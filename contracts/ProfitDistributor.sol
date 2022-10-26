// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "../chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "../openzeppelin-contracts-upgradeable-master/contracts/proxy/utils/Initializable.sol";
import "../openzeppelin-contracts-upgradeable-master/contracts/access/OwnableUpgradeable.sol";
import "../contracts/interfaces/IPureFiFarming2Verifiable.sol";
import "../openzeppelin-contracts-upgradeable-master/contracts/token/ERC20/IERC20Upgradeable.sol";
import "../chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "../contracts/interfaces/IProfitDistributor.sol";

contract ProfitDistributor is
    Initializable,
    OwnableUpgradeable,
    VRFConsumerBaseV2,
    AutomationCompatible,
    IProfitDistributor
{
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);
    event ProfitDistributed(address recepient, uint256 amount);

    struct WinInfo{
        uint64 timestamp;
        uint256 amount;
    }

    uint256 lastRequestId;
    uint256[] randomWords;

    uint64 subscriptionId;
    uint32 callbackGasLimit;
    uint32 numWords;

    VRFCoordinatorV2Interface COORDINATOR;

    IPureFiFarming2Verifiable farmingContract;

    IERC20Upgradeable pureFiToken;

    address subscriptionService;

    uint16 requestConfirmation;

    // true - if random words were gotten
    bool randomWordsFullfilledStatus; 
    // true - if request was sent, but random words were not received yet
    bool randomWordsPendingStatus;
    // true - if subscription service distributed profit
    bool distributionReadiness;
    // store the latest user win
    mapping (address => WinInfo) winners;
    // gas lane to use;
    // see for more info : https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
    bytes32 keyHash;

    function initialize(
        address _vrfCoordinator,
        uint64 _subscriptionId,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmation,
        uint32 _numWords,
        address _farmingContract,
        address _pureFiToken,
        address _subService
    ) public initializer {
        __VRFConsumerBaseV2_init(_vrfCoordinator);
        __Ownable_init();

        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
        callbackGasLimit = _callbackGasLimit;
        requestConfirmation = _requestConfirmation;
        numWords = _numWords;
        farmingContract = IPureFiFarming2Verifiable(_farmingContract);
        pureFiToken = IERC20Upgradeable(_pureFiToken);
        subscriptionService = _subService;

    }

    // request random words manually
    function requestRandomWords() public onlyOwner returns (uint256 requestId){
        return _requestRandomWords();
    }

    function _requestRandomWords() internal returns (uint256 requestId){
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmation,
            callbackGasLimit,
            numWords
        );
        lastRequestId = requestId;
        randomWordsPendingStatus = true;
        emit RequestSent( requestId, numWords );
        return requestId;
    }

    function fulfillRandomWords( uint256 _requestId, uint256[] memory _randomWords) internal override {
        require(lastRequestId == _requestId, 'Incorrect request_id');
        randomWords = _randomWords;

        emit RequestFulfilled(_requestId, _randomWords);
        randomWordsFullfilledStatus = true;
        randomWordsPendingStatus = false;
    }

    // distributeProfit manually
    function distributeProfit() external onlyOwner {
        _distributeProfit();
    }

    function _distributeProfit() internal {
        uint256 userAmount = farmingContract.getUsersAmount();

        require(userAmount != 0, "ProfitDistributor : Farming user amount can not be zero");
        
        uint256 winnerNumber;
        if( userAmount == 1 ){
            winnerNumber = 1;
        }else{
            winnerNumber = randomWords[0] % userAmount + 1;
        }
        address winner = farmingContract.getAddressById(winnerNumber);

        uint256 contractBalance = pureFiToken.balanceOf(address(this));

        bool res = pureFiToken.transfer(winner, contractBalance);
        require(res == true, "ProfitDistributor : transferFrom error");

        // add info about winner
        winners[winner] = WinInfo({timestamp : uint64(block.timestamp), amount : contractBalance});

        emit ProfitDistributed(winner, contractBalance);
        
        delete randomWords;
        randomWordsFullfilledStatus = false;
        distributionReadiness = false;

    }

    function getRandomWords() external view returns (uint256[] memory){
        return randomWords;
    }
    function getWinInfo( address _user) external view returns(uint64 timestamp, uint256 amount){
        WinInfo memory info = winners[_user];
        timestamp = info.timestamp;
        amount = info.amount;
    }

    function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData){
        if( distributionReadiness == true ){
            if(randomWordsFullfilledStatus == false && randomWordsPendingStatus == false){
                upkeepNeeded = true;
            }else if ( randomWordsFullfilledStatus == true && randomWordsPendingStatus == false ){
                upkeepNeeded = true;
            }
        }
    }

    function performUpkeep(bytes calldata performData) external{
        require( distributionReadiness == true, "Incorrect readiness status" );

        if( randomWordsFullfilledStatus == false && randomWordsPendingStatus == false ){
            _requestRandomWords();
        }else if(randomWordsFullfilledStatus == true && randomWordsPendingStatus == false){
            _distributeProfit();
        }
    }

    function setDistributionReadinessFlag() external {
        _isSubService();
        distributionReadiness = true;
    }

    function _isSubService() internal view {
        require(msg.sender == subscriptionService, "Unauthorized");
    }

    function getSubscriptionService() external view returns(address){
        return subscriptionService;
    }

    function setSubscriptionService(address _newSubService) external onlyOwner{
        subscriptionService = _newSubService;
    }

    function setSubscriptionId(uint64 _newId) external onlyOwner{
        subscriptionId = _newId;
    }

}
