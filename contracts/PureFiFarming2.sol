pragma solidity ^0.8.0;

import "../openzeppelin-contracts-upgradeable-master/contracts/token/ERC20/IERC20Upgradeable.sol";
import "../openzeppelin-contracts-upgradeable-master/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../openzeppelin-contracts-upgradeable-master/contracts/access/AccessControlUpgradeable.sol";
import "../openzeppelin-contracts-upgradeable-master/contracts/proxy/utils/Initializable.sol";
import "../openzeppelin-contracts-upgradeable-master/contracts/security/PausableUpgradeable.sol";
import "./interfaces/IPureFiFarming2Verifiable.sol";
import "./tokenbuyer/ITokenBuyer.sol";
import "./PureFiContext.sol";


// Derived from Sushi Farming contract

contract PureFiFarming2 is Initializable, AccessControlUpgradeable, PausableUpgradeable, IPureFiFarming2Verifiable, PureFiContext  {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    //ACL
    //Manager is the person allowed to manage pools
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 pendingReward; //how many tokens user was rewarded with, pending to withdraw
        uint256 totalRewarded; //total amount of tokens rewarded to user
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of Tokens
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accTokenPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accTokenPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20Upgradeable lpToken;           // Address of LP token contract.
        uint64 allocPoint;       // How many allocation points assigned to this pool. Tokens to distribute per block.
        uint64 startBlock;  // farming start block
        uint64 endBlock; // farming endBlock
        uint64 lastRewardBlock;  // Last block number that Tokens distribution occurs.
        uint256 accTokenPerShare; // Accumulated Tokens per share, times 1e12. See below.
        uint256 totalDeposited; //total tokens deposited in address of a pool

        address buyTokenAddress;
        uint256 commissionAmount;
    }

    // The Token TOKEN
    IERC20Upgradeable public rewardToken;
    // Token tokens created per block.
    uint256 public tokensFarmedPerBlock;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint16 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
     // Amount of users
    uint256 usersAmount;
    // timestamp until claiming rewards are disabled;
    uint64 public noRewardClaimsUntil;

    mapping (uint16 => mapping (address => uint64)) public userStakedTime;
    mapping (uint16 => uint64) public minStakingTimeForPool;
    mapping (uint16 => uint256) public maxStakingAmountForPool;

    // PersonId to UserAddress 
    mapping(uint => address) idToAddress;
    // Accordance between user address and Id
    mapping(address => uint) addressToId;
    // Accordance between user and amount of deposited pools
    mapping (address => uint16) addressToPools;


    // uint8 dexType; //1 for Uniswap v2, 2 for Pankcake v2

    uint32 private storageVersion;

    address public tokenBuyer;

    event PoolAdded(uint256 indexed pid);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amountLiquidity);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amountLiquidity);
    event RewardClaimed(address indexed user, uint256 indexed pid, uint256 amountRewarded);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amountLiquidity);
    event DepositCommission(address indexed user, uint256 indexed pid, uint256 commissionIn, address tokenOut, uint256 tokensOutAmount);

    function initialize(
        address _admin,
        address _rewardToken,
        uint256 _tokensPerBlock,
        uint64 _noRewardClaimsUntil,
        address _tokenBuyer,
        address _pureFiVerifier
    ) public initializer {
        __AccessControl_init();
        __Pausable_init_unchained();
        __PureFiContext_init_unchained( _pureFiVerifier);

        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(MANAGER_ROLE, _admin);

        rewardToken = IERC20Upgradeable(_rewardToken);
        tokensFarmedPerBlock = _tokensPerBlock;
        if(_noRewardClaimsUntil < block.timestamp){
            _noRewardClaimsUntil = uint64(block.timestamp);
        }
        // require (_noRewardClaimsUntil > block.timestamp, "Incorrect _noRewardClaimsUntil");
        noRewardClaimsUntil = _noRewardClaimsUntil;
        tokenBuyer = _tokenBuyer;
    }

    function version() public pure returns (uint32){
        //version in format aaa.bbb.ccc => aaa*1E6+bbb*1E3+ccc;
        return uint32(2000003);
    }

    function upgradeStorage() public {
        if(storageVersion < uint32(1002000)){
            for(uint i=0;i<poolInfo.length;i++){
                minStakingTimeForPool[uint16(i)] = 0;
            }            
        }
        storageVersion = version();
    }

    /**
    * @dev Throws if called by any account other than the one with the Manager role granted.
    */
    modifier onlyManager() {
        require(hasRole(MANAGER_ROLE, msg.sender), "Caller is not the Manager");
        _;
    }

    /**
    * @dev Throws if called by any account other than the one with the Admin role granted.
    */
    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not the Admin");
        _;
    }

    //************* MANAGER FUNCTIONS ********************************

    function setTokenPerBlock(uint256 _tokensFarmedPerBlock) public onlyManager {
        tokensFarmedPerBlock = _tokensFarmedPerBlock;
        massUpdatePools();
    }

    function setNoRewardClaimsUntil(uint64 _noRewardClaimsUntil) public onlyManager {
        require (_noRewardClaimsUntil > block.timestamp, "Incorrect _noRewardClaimsUntil");
        noRewardClaimsUntil = _noRewardClaimsUntil;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function addPool(uint64 _allocPoint, address _lpTokenAddress, uint64 _startBlock, uint64 _endBlock, uint64 _minStakingTime, uint256 _maxStakingAmount, bool _withUpdate) public onlyManager {
        require (block.number < _endBlock, "Incorrect endblock number");
        IERC20Upgradeable _lpToken = IERC20Upgradeable(_lpTokenAddress);
        if (_withUpdate) {
            massUpdatePools();
        }
        uint64 lastRewardBlock = block.number > _startBlock ? uint64(block.number) : _startBlock;
        totalAllocPoint += _allocPoint;
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            startBlock: _startBlock,
            endBlock: _endBlock,
            lastRewardBlock: lastRewardBlock,
            accTokenPerShare: 0,
            totalDeposited: 0,
            buyTokenAddress: address(0),
            commissionAmount: 0
        }));
        minStakingTimeForPool[uint16(poolInfo.length-1)] = _minStakingTime;
        maxStakingAmountForPool[uint16(poolInfo.length-1)] = _maxStakingAmount;

        emit PoolAdded(poolInfo.length-1);
    }

    function updatePoolStakingCommission(uint16 _pid, address _buyTokenAddress, uint256 _commission) public onlyManager {
        poolInfo[_pid].buyTokenAddress = _buyTokenAddress;
        poolInfo[_pid].commissionAmount = _commission;
    }

    // Update the given pool's Token allocation point. Can only be called by the owner.
    function updatePoolData(uint16 _pid, uint64 _allocPoint, uint64 _startBlock, uint64 _endBlock, uint64 _minStakingTime, uint256 _maxStakingAmount, bool _withUpdate) public onlyManager {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        minStakingTimeForPool[_pid] = _minStakingTime;
        maxStakingAmountForPool[_pid] = _maxStakingAmount;
        if(_startBlock > 0){
            poolInfo[_pid].startBlock = _startBlock;
        }
        if(_endBlock > 0){
            require (block.number < _endBlock, "Incorrect endblock number");
            poolInfo[_pid].endBlock = _endBlock;
        }
        if(_withUpdate){

        }
    }

    //************* ADMIN FUNCTIONS ********************************

    function withdrawRewardTokens(address _to, uint256 _amount) public onlyAdmin {
        rewardToken.safeTransfer(_to, _amount);
    }

    function setTokenBuyer(address _tokenBuyer) public onlyAdmin{
        tokenBuyer = _tokenBuyer;
    }

    function pause() onlyAdmin public {
        super._pause();
    }
   
    function unpause() onlyAdmin public {
        super._unpause();
    }

    //************* PUBLIC FUNCTIONS ********************************

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public whenNotPaused {
        _massUpdatePools();
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public whenNotPaused {
        _updatePool(_pid);
    }

    /**
    * @param data - signed data package from the off-chain verifier
    *    data[0] - verification session ID
    *    data[1] - rule ID (if required)
    *    data[2] - verification timestamp
    *    data[3] - verified wallet - to be the same as msg.sender
    * @param signature - Off-chain verifier signature
    */


    // Deposit LP tokens to PureFiFarming for Token allocation.
    function deposit(uint16 _pid, uint256 _amount, uint256[] memory data, bytes memory signature) public payable whenNotPaused {
        depositTo(_pid, _amount, msg.sender, data, signature);
    }

    // Deposit LP tokens to PureFiFarming for Token allocation.
    function depositTo(
        uint16 _pid,
         uint256 _amount,
          address _beneficiary,
          uint256[] memory data,
           bytes memory signature
           ) public payable override whenNotPaused compliesDefaultRule( DefaultRule.KYCAML, msg.sender, data, signature ) {

        _checkUserRegistration(_pid, _beneficiary);

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_beneficiary];
        require(_amount + user.amount <= maxStakingAmountForPool[_pid], "Deposited amount exceeded limits for this pool");
        if(pool.commissionAmount > 0) {
            require(msg.value >= pool.commissionAmount, "Insufficient commission sent");
        }

        uint256 tokensOutAmount = 0;
        
        if(pool.buyTokenAddress!= address(0)){
            require(tokenBuyer != address(0),"Token buyer not set");
            tokensOutAmount = ITokenBuyer(tokenBuyer).buyToken{value:msg.value}(pool.buyTokenAddress, _beneficiary);
        }

        emit DepositCommission(_beneficiary, _pid, msg.value, pool.buyTokenAddress, tokensOutAmount);

        updatePool(_pid);
        if (user.amount > 0) {
            user.pendingReward += user.amount * pool.accTokenPerShare / 1e12 - user.rewardDebt;
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount += _amount;
            pool.totalDeposited += _amount;
        }
        user.rewardDebt = user.amount * pool.accTokenPerShare / 1e12;
        userStakedTime[_pid][_beneficiary] = uint64(block.timestamp); //save last user staked time;
        emit Deposit(_beneficiary, _pid, _amount);
    }


    // Withdraw LP tokens from PureFiFarming.
    function withdraw( uint16 _pid, uint256 _amount) public override whenNotPaused
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        require(userStakedTime[_pid][msg.sender] == 0 || userStakedTime[_pid][msg.sender] + minStakingTimeForPool[_pid] <= block.timestamp || block.number >= pool.endBlock, "Withdrawing stake is not allowed yet");
        updatePool(_pid);
        user.pendingReward += user.amount * pool.accTokenPerShare / 1e12 - user.rewardDebt;
        if(_amount > 0) {
            user.amount -= _amount;
            pool.totalDeposited -= _amount;
            pool.lpToken.safeTransfer(msg.sender, _amount);
            emit Withdraw(msg.sender, _pid, _amount);
        }
        user.rewardDebt = user.amount * pool.accTokenPerShare / 1e12;   

        // update info about user id and pools 
        if ( user.amount == _amount ){
            _updateUserIndex(msg.sender);
        }
    }

    // Claim rewarded tokens from PureFiFarming.

    function claimReward( uint16 _pid ) public override whenNotPaused
    {
        require(block.timestamp >= noRewardClaimsUntil, "Claiming reward is not available yet");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        user.pendingReward += user.amount * pool.accTokenPerShare / 1e12 - user.rewardDebt;
        user.rewardDebt = user.amount * pool.accTokenPerShare / 1e12;
        if(user.pendingReward > 0){
            user.totalRewarded += user.pendingReward;
            uint256 pending = user.pendingReward;
            user.pendingReward = 0;
            _safeTokenTransfer(msg.sender, pending);
            emit RewardClaimed(msg.sender, _pid, pending);
        }     
    }

    // withdraw all liquidity and claim all pending reward
    // withdraw all liquidity and claim all pending reward
    function exit( uint16 _pid ) public override whenNotPaused
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        user.pendingReward += user.amount * pool.accTokenPerShare / 1e12 - user.rewardDebt;
        require(userStakedTime[_pid][msg.sender] == 0 || userStakedTime[_pid][msg.sender] + minStakingTimeForPool[_pid] <= block.timestamp || block.number >= pool.endBlock, "Withdrawing stake is not allowed yet");
        if(user.amount > 0) {
            uint256 amountLiquidity = user.amount;
            pool.totalDeposited -= amountLiquidity;
            user.amount = 0;
            pool.lpToken.safeTransfer(msg.sender, amountLiquidity);
            emit Withdraw(msg.sender, _pid, amountLiquidity);
        }
        if(user.pendingReward > 0){
            require(block.timestamp >= noRewardClaimsUntil, "Claiming reward is not available yet");
            user.totalRewarded += user.pendingReward;
            uint256 pending = user.pendingReward;
            user.pendingReward = 0;
            _safeTokenTransfer(msg.sender,pending);
            emit RewardClaimed(msg.sender, _pid, pending);
        }    
        user.rewardDebt = 0;   

         // update info about user id and pools 
        _updateUserIndex(msg.sender);
    
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint16 _pid) public override whenNotPaused {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        pool.totalDeposited -= amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);

        // update info about user id and pools 
        _updateUserIndex(msg.sender);
    }

    //************* VIEW FUNCTIONS ********************************

    function getContractData() external override view returns (uint256, uint256, uint64){
        return (tokensFarmedPerBlock, totalAllocPoint, noRewardClaimsUntil);
    }

    function getPoolLength() external override view returns (uint256) {
        return poolInfo.length;
    }

    function getPool(uint16 _index) external override view returns (address, uint256, uint64, uint64, uint64, uint256, uint256) {
        require (_index < poolInfo.length, "index incorrect");
        PoolInfo memory pool = poolInfo[_index];
        return (address(pool.lpToken), pool.allocPoint, pool.startBlock, pool.endBlock, pool.lastRewardBlock, pool.accTokenPerShare, pool.totalDeposited);
    }

    function getPoolMinStakingTime(uint16 _index) public view returns(uint64){
        require (_index < poolInfo.length, "index incorrect");
        return minStakingTimeForPool[_index];
    }

    function getPoolMaxStakingAmount(uint16 _index) public view returns(uint256){
        require (_index < poolInfo.length, "index incorrect");
        return maxStakingAmountForPool[_index];
    }

    function getPoolCommission(uint16 _index) public view returns(address, uint256){
        require (_index < poolInfo.length, "index incorrect");
        return (poolInfo[_index].buyTokenAddress, poolInfo[_index].commissionAmount);
    }
    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _pid, uint256 _from, uint256 _to) public view returns (uint256) {
        require (_from <= _to, "incorrect from/to sequence");
        if (poolInfo[_pid].startBlock == 0 || _to <= poolInfo[_pid].startBlock || _from >= poolInfo[_pid].endBlock) {
            return 0;
        }

        uint256 lastBlock = _to <= poolInfo[_pid].endBlock ? _to : poolInfo[_pid].endBlock;
        uint256 firstBlock = _from >= poolInfo[_pid].startBlock ? _from : poolInfo[_pid].startBlock;
        return lastBlock - firstBlock;
    }

    // View function to see pending Tokens on frontend.
    function getUserInfo(uint16 _pid, address _user) external override view returns (uint256, uint256, uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accTokenPerShare = pool.accTokenPerShare;
        if (block.number > pool.lastRewardBlock && pool.totalDeposited != 0) {
            uint256 multiplier = getMultiplier(_pid, pool.lastRewardBlock, block.number);
            uint256 amountRewardedPerPool = totalAllocPoint > 0 ? (multiplier * tokensFarmedPerBlock * pool.allocPoint / totalAllocPoint) : 0;
            accTokenPerShare += amountRewardedPerPool * 1e12 / pool.totalDeposited;
        }
        return (user.amount, user.totalRewarded, user.pendingReward + user.amount * accTokenPerShare / 1e12 - user.rewardDebt);
    }

    function getUserStakedTime(uint16 _pid, address _user) external view returns(uint64) {
        return userStakedTime[_pid][_user];
    }

    function getAddressById( uint256 _id ) external view returns (address){
        return _getAddressById(_id);
    }

    function getAddressByIds( uint256[] memory _ids ) external view returns(address[] memory) {
        address[] memory users = new address[](_ids.length);

        for( uint i = 0; i < _ids.length; i++){
            users[i] = idToAddress[_ids[i]];
        }
        return users;
    }
    //************* INTERNAL FUNCTIONS ********************************

    // Safe rewardToken transfer function, just in case if rounding error causes pool to not have enough Tokens.
    function _safeTokenTransfer(address _to, uint256 _amount) internal {
        uint256 tokenBal = rewardToken.balanceOf(address(this));
        if (_amount > tokenBal) {
            rewardToken.transfer(_to, tokenBal);
        } else {
            rewardToken.transfer(_to, _amount);
        }
    }

    function _massUpdatePools() internal {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            _updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function _updatePool(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        if (pool.totalDeposited == 0) {
            pool.lastRewardBlock = uint64(block.number);
            return;
        }
        uint256 multiplier = getMultiplier(_pid, pool.lastRewardBlock, block.number);
        uint256 amountRewardedPerPool = totalAllocPoint > 0 ? (multiplier * tokensFarmedPerBlock * pool.allocPoint / totalAllocPoint) : 0;
        pool.accTokenPerShare += amountRewardedPerPool * 1e12 / pool.totalDeposited;
        pool.lastRewardBlock = uint64(block.number);
    }

    function _getAddressById( uint256 _id ) internal view returns (address){
        return idToAddress[_id];
    }

    function _addUser( address _newUser ) internal {
        usersAmount++;
        uint256 index = usersAmount;
        idToAddress[index] = _newUser;
        addressToId[_newUser] = index;
        addressToPools[_newUser] = 1;
    }

    function _addPool( address _user ) internal {
        addressToPools[_user] += 1;
    }

    function _isRegistered( address _user ) internal view returns (bool){
        if ( addressToId[_user] == 0 ){
            return false;
        }else{
            return true;
        }
    }

    function _checkUserRegistration( uint16 _pid, address _user ) internal{
        UserInfo memory user = userInfo[_pid][_user];
        // check if it is first deposit to this pool
        if( user.amount == 0 ){
            if( !_isRegistered(_user) ){
                _addUser(_user);
            }else{
                _addPool(_user);
            }
        }
    }

    function _updateUserIndex( address _user ) internal{
        if( addressToPools[_user] == 1 ){
            _removeUser(_user);
        }else{
            _removePool(_user);
        }
    }

    function _removeUser( address _user ) internal{
        uint256 removedUserId = addressToId[_user];

        _reorderId(removedUserId);

        usersAmount -= 1;
        delete addressToId[_user];
        delete addressToPools[_user];
        
    }

    function _removePool( address _user ) internal {
        addressToPools[_user] -= 1;
    }

    function _lastUserIndex() internal view returns (uint256){
        return usersAmount;
    }

    function _reorderId( uint256 _removedId ) internal {
        if ( _removedId != _lastUserIndex()) {
            address lastIndexUser = idToAddress[_lastUserIndex()];
            idToAddress[_removedId] = lastIndexUser;
            delete idToAddress[_lastUserIndex()];
            addressToId[lastIndexUser] = _removedId;
        }else{
            delete idToAddress[_removedId];
        }
    }
}