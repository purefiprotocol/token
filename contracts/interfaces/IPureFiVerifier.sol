// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

 struct VerificationData{
        uint8 typ;
        address from;
        address to;
        address token;
        uint256 amount;
        bytes payload;
    }
interface IPureFiVerifier{

    function verifyIssuerSignature(uint256[] memory data, bytes memory signature) external view returns (bool);
    function defaultAMLCheck(uint256[] memory data, bytes memory signature) external view returns (VerificationData memory, uint16);
    function defaultKYCCheck(uint256[] memory data, bytes memory signature) external view returns (VerificationData memory, uint16);
    function defaultKYCAMLCheck(uint256[] memory data, bytes memory signature) external view returns (VerificationData memory, uint16);
    function verifyAgainstRule(uint256[] memory data, bytes memory signature) external view returns (VerificationData memory, uint16);
    function verifyAgainstRuleIM(uint256[] memory data, bytes memory signature) external view returns (VerificationData memory, uint16);
    function verifyAgainstRuleW(address expectedFundsSender, uint256 expectedRuleID) external view returns (uint16, string memory);  
}