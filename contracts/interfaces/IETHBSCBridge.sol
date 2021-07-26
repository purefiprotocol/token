// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

interface IETHBSCBridge {
    function registerSwapPairToBSC(address erc20Addr) external returns (bool);
    function swapETH2BSC(address erc20Addr, uint256 amount) payable external returns (bool);
    function fillBSC2ETHSwap(bytes32 bscTxHash, address erc20Addr, address toAddress, uint256 amount) external returns (bool); 
}
