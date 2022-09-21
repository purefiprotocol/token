// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface IPureFiVerifier{
    function verifyIssuerSignature(uint256[] memory data, bytes memory signature) external view returns (bool);
    function defaultAMLCheck(address expectedFundsSender, uint256[] memory data, bytes memory signature) external view returns (uint16, string memory);
    function defaultKYCCheck(address expectedFundsSender, uint256[] memory data, bytes memory signature) external view returns (uint16, string memory);
    function defaultKYCAMLCheck(address expectedFundsSender, uint256[] memory data, bytes memory signature) external view returns (uint16, string memory);
    function verifyAgainstRule(address expectedFundsSender, uint256 expectedRuleID, uint256[] memory data, bytes memory signature) external view returns (uint16, string memory);
    function verifyAgainstRuleIM(address expectedFundsSender, uint256 expectedRuleID, uint256[] memory data, bytes memory signature) external view returns (uint16, string memory);
    function verifyAgainstRuleW(address expectedFundsSender, uint256 expectedRuleID) external view returns (uint16, string memory);  
}