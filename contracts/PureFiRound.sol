// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../openzeppelin-contracts-upgradeable-master/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../openzeppelin-contracts-upgradeable-master/contracts/proxy/utils/Initializable.sol";
import "../openzeppelin-contracts-upgradeable-master/contracts/access/OwnableUpgradeable.sol";
import "../openzeppelin-contracts-upgradeable-master/contracts/security/PausableUpgradeable.sol";
import "../openzeppelin-contracts-upgradeable-master/contracts/metatx/ERC2771ContextUpgradeable.sol";
import "./interfaces/IPureFiFarming.sol";

interface IToken {
    function decimals() external view returns(uint8);
}

contract PureFiRound is Initializable, OwnableUpgradeable, PausableUpgradeable, ERC2771ContextUpgradeable {

    using SafeERC20Upgradeable for IERC20Upgradeable;
    
    uint32 public constant BOOSTER_DENOM = 100;

    address public tokenX; // address of X token contract
    address public tokenUFI; //address of UFI token contract
    uint256 public priceUSDperX; // price of the X token in USD.
    uint256 public priceUSDperUFI; //price of the UFI token in USD.
    uint256 public totalAmountX; //total amount of tokenX distributed within the round
    uint256 public exactRoundSizeInUFI; // exact amount of UFI tokens that will be returned to the round beneficiary.
    uint256 public amountOversubscribed; //amount of the oversubsciption tokens in UFI
    uint256 public totalShares; // total amount of shares invested
    address public beneficiary;
    address public farmingContract;
    uint8 public farmingContractPoolIndex;
    Status public roundStatus;
    uint64 private roundStartDate; //round start date
    uint64 private noUFIClaimUntil; // no UFI can be claimed back by users until this date. 
    uint64 private XListingDate; //timestamp of the listing event of the token X. 20% of X is unlocked and can be claimed by users after this date. remaining tokens are linearly vested over time until XVestingEndDate;
    uint64 private XVestingEndDate; // 80% of X tokens are linearly vested over time until XVestingEndDate;

    Booster[] private boosters;
    
    mapping (address => UserData) private depositList;

    struct Booster{
        uint64 date;
        uint32 booster;
    }

    struct UserData {
        uint256 amountUFIDeposited; // amount of UFI deposited by the user
        uint256 amountShares; // this is the amount of shares in pool
        uint256 amountXWithdrawn; // amount of X tokens already withdrawn by the user
        uint256 amountUFIWithdrawn; // amount of UFI tokens already withdrawn by the user
    }

    enum Status {
        New,
        Active,
        Successful,
        Failed
    }

    
    event UserDeposit(address indexed user, uint256 usersUFI);
    event UserWithdrawal(address indexed user, address tokenContract, uint256 withdrawnAmount);
    event SuccessfulRound(uint256 priceX, uint256 priceUSDperUFI, uint256 totalAmountX, uint256 amountUFI);
    event FailedRound(uint256 priceX, uint256 priceUSDperUFI, uint256 totalAmountX, uint256 amountUFI);

    function _msgSender() internal override(ContextUpgradeable, ERC2771ContextUpgradeable) view returns (address) {
        return ERC2771ContextUpgradeable._msgSender();
    }
    function _msgData() internal override(ContextUpgradeable, ERC2771ContextUpgradeable) view returns (bytes calldata) {
        return ERC2771ContextUpgradeable._msgData();
    }

    function initialize(
        address _tokenX,
        address _tokenUFI
    ) public initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        __Pausable_init_unchained();
        tokenX = _tokenX;
        tokenUFI = _tokenUFI;
        beneficiary = owner();
        require(IToken(tokenUFI).decimals() >= IToken(tokenX).decimals(),"Unsupported token decimals");

        boosters.push(Booster(1*86400, 250));
        boosters.push(Booster(2*86400, 180));
        boosters.push(Booster(3*86400, 150));
        boosters.push(Booster(4*86400, 120));
        boosters.push(Booster(5*86400, 110));
        boosters.push(Booster(12*86400, 100));
    }

    function version() public pure returns (uint32){
        //version in format aaa.bbb.ccc => aaa*1E6+bbb*1E3+ccc;
        return uint32(2000004);
    }

    function activate() external onlyOwner {
        // Lets users deposit into the pool.
        // Stops owner from changing price of token X
        // or withdrawing tokens from the pool
        // but lets owner deposit additional tokens to the pool
        require(roundStatus == Status.New, "The round have ended or is active already.");
        roundStatus = Status.Active;
    }

    function pause() external onlyOwner {
        require(roundStatus == Status.New || roundStatus == Status.Active, "The round have ended.");
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setDateRestrictions(uint64 _noUFIClaimsUntil, uint64 _XListingDate, uint64 _XVestingEndDate, uint64 _roundStartDate) external onlyOwner{
        noUFIClaimUntil = _noUFIClaimsUntil;
        XListingDate = _XListingDate;
        XVestingEndDate = _XVestingEndDate;
        roundStartDate = _roundStartDate;
    }

    function setFarmingContract(address _farmingContract, uint8 _poolIndex) external onlyOwner{
        farmingContract = _farmingContract;
        farmingContractPoolIndex = _poolIndex;
    }

    function setBeneficiary(address _beneficiary) external onlyOwner {
        beneficiary = _beneficiary;
    }

    function setTokenX(address _tokenX) external onlyOwner{
        tokenX = _tokenX;
    }

    function setPriceX(uint256 _priceUSDperX) external onlyOwner {
        priceUSDperX = _priceUSDperX;
    }

    function depositToPoolX(uint256 poolX) external onlyOwner {
        require(roundStatus == Status.New || roundStatus == Status.Active, "The round have ended or is active.");
        totalAmountX += poolX;
        IERC20Upgradeable(tokenX).safeTransferFrom(_msgSender(), address(this), poolX);
    }

    function withdrawFromPoolX() external onlyOwner {
        require(roundStatus == Status.New || roundStatus == Status.Failed , "The round is active or have ended.");
        IERC20Upgradeable(tokenX).safeTransfer(
            beneficiary,
            IERC20Upgradeable(tokenX).balanceOf(address(this))
        );
        totalAmountX = 0;
    }

    function depositUFI(uint256 _amountUFI) external whenNotPaused {
        _depositUFIto(_amountUFI,_msgSender());
    }

    function depositUFIto(uint256 _amountUFI, address _to) external whenNotPaused {
        _depositUFIto(_amountUFI, _to);
    }


    function withdrawUFI() external whenNotPaused {
        uint256 ufiAvailableToClaim = _availableUFI(_msgSender());
        if(ufiAvailableToClaim > 0){
            depositList[_msgSender()].amountUFIWithdrawn += ufiAvailableToClaim;
            IERC20Upgradeable(tokenUFI).safeTransfer(
                _msgSender(),
                ufiAvailableToClaim
            );
            emit UserWithdrawal(
                _msgSender(),
                tokenUFI,
                ufiAvailableToClaim
            );
        }
    }

    function claimX() external whenNotPaused{
        uint256 xAvailableToClaim = _availableX(_msgSender());
        if(xAvailableToClaim > 0){
            depositList[_msgSender()].amountXWithdrawn += xAvailableToClaim;
            IERC20Upgradeable(tokenX).safeTransfer(
                _msgSender(),
                xAvailableToClaim
            );
            emit UserWithdrawal(
                _msgSender(),
                tokenX,
                xAvailableToClaim
            );
        } 
    }

    function withdrawUFIAndStake() public whenNotPaused{
        require(farmingContract != address(0),"Farming contract is not defined");
        uint256 ufiAvailableToClaim = _availableUFI(_msgSender());
        if(ufiAvailableToClaim > 0){
            depositList[_msgSender()].amountUFIWithdrawn += ufiAvailableToClaim;
            IERC20Upgradeable(tokenUFI).safeApprove(farmingContract, ufiAvailableToClaim);
            IPureFiFarming(farmingContract).depositTo(farmingContractPoolIndex, ufiAvailableToClaim, _msgSender());
            emit UserWithdrawal(
                _msgSender(),
                tokenUFI,
                ufiAvailableToClaim
            );
        }
    }

    function endRound(uint256 _priceUSDperUFI) external onlyOwner {
        require(roundStatus == Status.Active, "The round isn't active.");
        uint256 contractTokenBalanceInUFI = IERC20Upgradeable(tokenUFI).balanceOf(address(this));
        uint8 deltaDecimals = IToken(tokenUFI).decimals() - IToken(tokenX).decimals();
        priceUSDperUFI = _priceUSDperUFI;
        uint256 depositedTotalInUSD = contractTokenBalanceInUFI * _priceUSDperUFI;
        uint256 roundHardCapInUSD = totalAmountX * priceUSDperX * (10 ** deltaDecimals);
        if (roundHardCapInUSD <= depositedTotalInUSD) {
            roundStatus = Status.Successful;
            emit SuccessfulRound(priceUSDperX, priceUSDperUFI, totalAmountX, contractTokenBalanceInUFI);
            exactRoundSizeInUFI = roundHardCapInUSD / _priceUSDperUFI;
            if(exactRoundSizeInUFI > contractTokenBalanceInUFI) //omit possible rounding issue
                exactRoundSizeInUFI = contractTokenBalanceInUFI;
            IERC20Upgradeable(tokenUFI).safeTransfer(
                beneficiary,
                exactRoundSizeInUFI
            );
            amountOversubscribed = contractTokenBalanceInUFI - exactRoundSizeInUFI;
        }
        else {
            roundStatus = Status.Failed;
            emit FailedRound(priceUSDperX, _priceUSDperUFI, totalAmountX, contractTokenBalanceInUFI);
        }
    }

    function availableTokens(address _user) public view returns (uint256, uint256){
        return (_availableUFI(_user), _availableX(_user));
    }

    function userData(address _user) public view returns (uint256, uint256, uint256, uint256, uint256, uint256){
        return (depositList[_user].amountUFIDeposited,
                depositList[_user].amountUFIWithdrawn,
                depositList[_user].amountXWithdrawn,
                depositList[_user].amountShares,
                _availableUFI(_user),
                _availableX(_user));
    }

    function getDateRestrictions() public view returns (uint64, uint64, uint64){
        return (noUFIClaimUntil, XListingDate, XVestingEndDate);
    }

    function getStatus() external view returns(Status) {
        return roundStatus;
    }

    function currentBoosterValue() external view returns (uint32) {
        return _currentBoosterValue();
    }

    function _currentBoosterValue() private view returns (uint32) {
        if(block.timestamp < roundStartDate)
            return 0;
        else {
            for(uint i=0; i<boosters.length;i++){
                if(block.timestamp < roundStartDate+boosters[i].date)
                    return boosters[i].booster;
            }
            return 0;
        }
    }

    function _availableUFI(address _user) private view returns (uint256) {
        uint256 availableUFIToClaim;
        if(block.timestamp < noUFIClaimUntil) {
            availableUFIToClaim = 0;
        }else{
            if(roundStatus == Status.Failed) {
                availableUFIToClaim = depositList[_user].amountUFIDeposited - depositList[_user].amountUFIWithdrawn;
            } else if(roundStatus == Status.Successful){
                availableUFIToClaim = depositList[_user].amountUFIDeposited * amountOversubscribed / (amountOversubscribed + exactRoundSizeInUFI) - depositList[_user].amountUFIWithdrawn;
            } else {
                availableUFIToClaim = 0;
            }
        }
        return availableUFIToClaim;
    }

    function _availableX(address _user) private view returns (uint256) {
        uint256 availableXtoClaim = 0;
        if(block.timestamp >= XListingDate && roundStatus == Status.Successful){
            uint256 totalUsersX = depositList[_user].amountShares * totalAmountX / totalShares;
            uint256 vestingTimestamp = (block.timestamp > XVestingEndDate)? XVestingEndDate : block.timestamp; //set max time to XVestingEndDate
            uint256 currentlyUnlockedX = 20 * totalUsersX / 100 + 80 * (vestingTimestamp - XListingDate) * totalUsersX / (100 * (XVestingEndDate - XListingDate));
            availableXtoClaim =  currentlyUnlockedX - depositList[_user].amountXWithdrawn;
        } 
        return availableXtoClaim;
    }

    function _depositUFIto(uint256 _amountUFI, address _user) internal {
        require(roundStatus == Status.Active, "The round isn't active.");
        uint32 currentBooster = _currentBoosterValue();
        require(currentBooster > 0, "Round has not started or is already finished");
        IERC20Upgradeable(tokenUFI).safeTransferFrom(_msgSender(), address(this), _amountUFI);
        depositList[_user].amountUFIDeposited += _amountUFI;
        uint256 userShares = _amountUFI * currentBooster / BOOSTER_DENOM;
        depositList[_user].amountShares += userShares;
        totalShares += userShares;
        emit UserDeposit(_user, _amountUFI);
    }
}