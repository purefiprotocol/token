// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "../chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "../chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "../openzeppelin-contracts-upgradeable-master/contracts/proxy/utils/Initializable.sol";
import "../openzeppelin-contracts-upgradeable-master/contracts/access/OwnableUpgradeable.sol";
import "../contracts/interfaces/IPureFiFarming2Verifiable.sol";
import "../openzeppelin-contracts-upgradeable-master/contracts/token/ERC20/IERC20Upgradeable.sol";

contract ProfitDistributor is
    Initializable,
    OwnableUpgradeable,
    VRFConsumerBaseV2
{
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);
    event ProfitDistributed(address recepient, uint256 amount);

    uint256 lastRequestId;
    uint256[] randomWords;

    uint64 subscriptionId;
    uint32 callbackGasLimit;
    uint32 numWords;

    VRFCoordinatorV2Interface COORDINATOR;

    IPureFiFarming2Verifiable farmingContract;

    IERC20Upgradeable pureFiToken;

    uint16 requestConfirmation;
    
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
        address _pureFiToken
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

    }

    function requestRandomWords() external onlyOwner returns (uint256 requestId){
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmation,
            callbackGasLimit,
            numWords
        );
        lastRequestId = requestId;
        emit RequestSent( requestId, numWords );
        return requestId;
    }

    function fulfillRandomWords( uint256 _requestId, uint256[] memory _randomWords) internal override {
        require(lastRequestId == _requestId, 'Incorrect request_id');
        randomWords = _randomWords;

        emit RequestFulfilled(_requestId, _randomWords);
    }

    function distributeProfit() external {
        //TODO: add modifier;
        uint256 userAmount = farmingContract.getUsersAmount();
        uint256[] memory normalizedNumbers;
        for(uint i = 0; i < randomWords.length; i++){
            normalizedNumbers[i] = randomWords[i] % userAmount + 1;
        }
        address[] memory winners = farmingContract.getAddressByIds( normalizedNumbers );

        require(normalizedNumbers.length == 3, 'Incorrect amount of users');
        uint256 contractBalance = pureFiToken.balanceOf(address(this));

        uint256 firstReward = contractBalance * 6 / 10;
        uint256 secondReward = contractBalance * 3 / 10;
        uint256 thirdReward = contractBalance / 10;

        pureFiToken.transfer(winners[0], firstReward);
        pureFiToken.transfer(winners[1], secondReward);
        pureFiToken.transfer(winners[2], thirdReward);

        emit ProfitDistributed(winners[0], firstReward);
        emit ProfitDistributed(winners[1], secondReward);
        emit ProfitDistributed(winners[2], thirdReward);
        delete randomWords;
    }

    function getRandomWords() external view returns (uint256[] memory){
        return randomWords;
    }
}
