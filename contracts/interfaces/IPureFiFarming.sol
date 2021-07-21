// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPureFiFarming{
    function depositTo(uint16 _pid, uint256 _amount, address _beneficiary) external;
    function deposit(uint16 _pid, uint256 _amount) external;
    function withdraw(uint16 _pid, uint256 _amount) external;
    function claimReward(uint16 _pid) external;
    function exit(uint16 _pid) external;
    function emergencyWithdraw(uint16 _pid) external;
    function getPoolLength() external view returns (uint256);
    function getPool(uint16 _index) external view returns (address, uint256, uint64, uint64, uint64, uint256, uint256);
    function getUserInfo(uint16 _pid, address _user) external view returns (uint256, uint256, uint256);
}
