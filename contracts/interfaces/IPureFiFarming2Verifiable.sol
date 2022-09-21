// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPureFiFarming2Verifiable{
    function depositTo(uint16 _pid, uint256 _amount, address _beneficiary, uint256[] memory data, bytes memory signature) external payable;
    function deposit(uint16 _pid, uint256 _amount, uint256[] memory data, bytes memory signature) external payable;
    function withdraw(uint16 _pid, uint256 _amount, uint256[] memory data, bytes memory signature) external;
    function claimReward(uint16 _pid, uint256[] memory data, bytes memory signature) external;
    function exit(uint16 _pid, uint256[] memory data, bytes memory signature) external;
    function emergencyWithdraw(uint16 _pid) external;
    function getContractData() external view returns (uint256, uint256, uint64);
    function getPoolLength() external view returns (uint256);
    function getPool(uint16 _index) external view returns (address, uint256, uint64, uint64, uint64, uint256, uint256);
    function getUserInfo(uint16 _pid, address _user) external view returns (uint256, uint256, uint256);
}
