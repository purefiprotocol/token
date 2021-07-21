// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IBotProtector {
    function isPotentialBot(address account) external returns (bool);
    function isPotentialBotTransfer(address from, address to) external returns (bool);
}