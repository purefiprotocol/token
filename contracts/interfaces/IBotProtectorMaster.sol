// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IBotProtectorMaster {
    function isPotentialBot(address account) external returns (bool);
    function isPotentialBotTransfer(address from, address to) external returns (bool);
    function setBotBlacklist(address account, bool isBlacklisted, uint256 debounceTime) external;
    function setBotProtectionDebounceTime(uint256 time) external;
    function setBotWhitelists(address[] calldata accounts) external;
    function setBotWhitelist(address account, bool isWhitelisted) external;
    function setBotLaunchpad(address launchpad) external;
    function finalizeBotProtection() external;
    function prepareBotProtection(uint256 firewallBlockLength, uint256 firewallTimeLength) external;
}
