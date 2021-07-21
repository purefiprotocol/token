// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "../openzeppelin-contracts-master/contracts/access/Ownable.sol";
import "../openzeppelin-contracts-master/contracts/utils/Context.sol";
import "./interfaces/IBotProtectedV1Token.sol";
import "./interfaces/IBotProtector.sol";

contract PureFiBotProtection is Context, Ownable, IBotProtectedV1Token, IBotProtector{

    // --==[ ADDRESSES ]==--
    address public botLaunchpad;
    address public tokenProtected;//erc20 token protected by this contract

    // --==[ PROTECTION ]==--
    mapping(address => bool) private botWhitelist;
    mapping(address => uint256) private botDebounceTime;

    bool private botProtectionIsActive = false;
    uint256 private botProtectionEndBlock = 0;
    uint256 private botProtectionEndTime = 0;
    uint256 private botProtectionDebounceTime = 10 seconds;

    address[] private bots;

    // --==[ Events ]==--
    event BotDetected(address indexed bot);
    event BotProtectionOperatorChanged(address indexed operator);
    event BotProtectionLaunchpadChanged(address indexed launchpad);

    modifier onlyLaunchpad() {
        require(botLaunchpad == _msgSender(), "PureFiBotProtection: only launchpad can call this function");
        _;
    }

    modifier onlyProtectedToken() {
        require(tokenProtected == _msgSender(), "PureFiBotProtection: only protected token can call this function");
        _;
    }

    constructor(address _operator, address _tokenProtected) {
        transferOwnership(_operator);
        botWhitelist[_operator] = true;
        tokenProtected = _tokenProtected;
    }

    function getBotsLength() external view returns (uint256) {
        return bots.length;
    }

    function prepareBotProtection(uint256 firewallBlockLength, uint256 firewallTimeLength) external override onlyLaunchpad {
        require(!botProtectionIsActive, "PureFiBotProtection: bot protection is active");

        botProtectionIsActive = true;
        botProtectionEndBlock = block.number + firewallBlockLength;
        botProtectionEndTime = block.timestamp + firewallTimeLength;
    }

    function finalizeBotProtection() external onlyOwner {
        botProtectionIsActive = false;
        botProtectionEndBlock = 0;
        botProtectionEndTime = 0;
    }

    function setTokenProtected(address _tokenContract) external onlyOwner{
        require(tokenProtected != _tokenContract, "PureFiBotProtection: tokenProtected is the same");
        tokenProtected = _tokenContract;
    }

    function setBotLaunchpad(address launchpad) external onlyOwner {
        require(botLaunchpad != launchpad, "PureFiBotProtection: launchpad is the same");
        botLaunchpad = launchpad;
        emit BotProtectionLaunchpadChanged(launchpad);
    }

    function setBotWhitelist(address account, bool isWhitelisted) external onlyOwner {
        botWhitelist[account] = isWhitelisted;
        if (isWhitelisted) {
            botDebounceTime[account] = 0;
        }
    }

    function setBotWhitelists(address[] calldata accounts) external onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            if(botWhitelist[accounts[i]] == false) {
                botWhitelist[accounts[i]] = true;
            }
        }
    }

    function setBotBlacklist(address account, bool isBlacklisted, uint256 debounceTime) external onlyOwner {
        if (isBlacklisted) {
            _addToBotList(account, debounceTime);
        } else {
            botDebounceTime[account] = 0;
        }
    }

    function setBotBlacklists(address[] calldata accounts, uint256 debounceTime) external onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            _addToBotList(accounts[i], debounceTime);
        }
    }

    function setBotProtectionDebounceTime(uint256 time) external onlyOwner {
        botProtectionDebounceTime = time;
    }

    function isPotentialBot(address account) external override onlyProtectedToken returns (bool){
        return _isPotentialBot(account);
    }

    function isPotentialBotTransfer(address from, address to) external override onlyProtectedToken returns (bool){
        return _isPotentialBot(from) || _isPotentialBot(to);
    }

    function _isPotentialBot(address account) internal returns (bool) {
        if (!botProtectionIsActive) return false;
        if (botWhitelist[account]) return false;

        uint256 blockTimestamp = block.timestamp;
        if (botProtectionEndBlock >= block.number || botProtectionEndTime >= blockTimestamp) {
            _addToBotList(account, botProtectionDebounceTime);
            return true;
        } else if (botDebounceTime[account] >= blockTimestamp) {
            _increaseDebounceTime(account, botProtectionDebounceTime);
            return true;
        }

        return false;
    }

    function _addToBotList(address bot, uint256 debounceTime) private {
        if (botDebounceTime[bot] == 0) {
            bots.push(bot);
        }

        _increaseDebounceTime(bot, debounceTime);

        emit BotDetected(bot);
    }

    function _increaseDebounceTime(address bot, uint256 debounceTime) private {
        if (botDebounceTime[bot] == 0) {
            botDebounceTime[bot] = block.timestamp + debounceTime;
        } else {
            botDebounceTime[bot] += debounceTime;
        }
    }
}