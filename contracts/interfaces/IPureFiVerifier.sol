// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

 struct VerificationPackage{
        uint8 packagetype;
        uint256 session;
        uint256 rule;
        address from;
        address to;
        address token;
        uint256 amount;
        bytes payload;
    }

interface IPureFiVerifier{

    // function verifyIssuerSignature(uint256[] memory data, bytes memory signature) external view returns (bool);
    // function defaultAMLCheck(uint256[] memory data, bytes memory signature) external view returns (VerificationData memory, uint16);
    // function defaultKYCCheck(uint256[] memory data, bytes memory signature) external view returns (VerificationData memory, uint16);
    // function defaultKYCAMLCheck(uint256[] memory data, bytes memory signature) external view returns (VerificationData memory, uint16);
    function validatePureFiData(bytes memory _purefidata) external view returns (bytes memory, uint16);
    function decodePureFiPackage(bytes memory _purefipackage) external view returns (VerificationPackage memory);
    // function verifyAgainstRuleIM(bytes memory _purefidata) external view returns (VerificationData memory, uint16);
    // function verifyAgainstRuleW(address expectedFundsSender, uint256 expectedRuleID) external view returns (uint16, string memory);  
}