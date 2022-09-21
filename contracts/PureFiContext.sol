// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../openzeppelin-contracts-upgradeable-master/contracts/proxy/utils/Initializable.sol";
import "./interfaces/IPureFiVerifier.sol";

abstract contract PureFiContext is Initializable{

    enum DefaultRule {NONE, KYC, AML, KYCAML} 
    
    uint256 internal constant _NOT_VERIFIED = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffa;
    uint256 internal constant _VERIFICATION_SUCCESS = 0;
    string internal constant _NOT_VERIFIED_REASON = "PureFi: Not verified";


    uint256 private _txLocalCheckResult; //similar to re-entrancy guard status or ThreadLocal in Java
    string private _txLocalCheckReason; //similar to re-entrancy guard status or ThreadLocal in Java
    
    IPureFiVerifier internal pureFiVerifier;

    function __PureFiContext_init_unchained(address _pureFiVerifier) internal initializer{
        _txLocalCheckResult = _NOT_VERIFIED;
        _txLocalCheckReason = _NOT_VERIFIED_REASON;
        pureFiVerifier = IPureFiVerifier(_pureFiVerifier);
    }

    modifier rejectUnverified() {
        require(_txLocalCheckResult == _VERIFICATION_SUCCESS, _txLocalCheckReason);
        _;
    }

    modifier requiresOnChainKYC(address user){
        uint256[] memory data = new uint256[](4);
        bytes memory signature;
        (_txLocalCheckResult, _txLocalCheckReason) = pureFiVerifier.defaultKYCCheck(user, data, signature);
        require(_txLocalCheckResult == _VERIFICATION_SUCCESS, _txLocalCheckReason);
        //here the smart contract can decide whether to fail a transaction in case of check failed

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _txLocalCheckResult = _NOT_VERIFIED;
        _txLocalCheckReason = _NOT_VERIFIED_REASON;
    }


    modifier compliesDefaultRule(DefaultRule rule, address expectedFundsSender, uint256[] memory data, bytes memory signature) {
        // set context variable
        if(rule == DefaultRule.NONE){
            _txLocalCheckResult = _VERIFICATION_SUCCESS;
        } else {
            if(rule == DefaultRule.KYC){
                (_txLocalCheckResult, _txLocalCheckReason) = pureFiVerifier.defaultKYCCheck(expectedFundsSender, data, signature);
            } else if (rule == DefaultRule.AML){
                (_txLocalCheckResult, _txLocalCheckReason) = pureFiVerifier.defaultAMLCheck(expectedFundsSender, data, signature);
            } else if (rule == DefaultRule.KYCAML){
                (_txLocalCheckResult, _txLocalCheckReason) = pureFiVerifier.defaultKYCAMLCheck(expectedFundsSender, data, signature);
            }
            require(_txLocalCheckResult == _VERIFICATION_SUCCESS, _txLocalCheckReason);
        }
        
        //here the smart contract can decide whether to fail a transaction in case of check failed

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _txLocalCheckResult = _NOT_VERIFIED;
        _txLocalCheckReason = _NOT_VERIFIED_REASON;
    }

    modifier compliesCustomRule(uint256 expectedRuleID, address expectedFundsSender, uint256[] memory data, bytes memory signature) {

        (_txLocalCheckResult, _txLocalCheckReason) = pureFiVerifier.verifyAgainstRule(expectedFundsSender, expectedRuleID, data, signature);
        require(_txLocalCheckResult == _VERIFICATION_SUCCESS, _txLocalCheckReason);
        
        //here the smart contract can decide whether to fail a transaction in case of check failed

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _txLocalCheckResult = _NOT_VERIFIED;
        _txLocalCheckReason = _NOT_VERIFIED_REASON;
    }

}
