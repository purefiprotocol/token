// SPDX-License-Identifier: GPL-2.0-or-later


pragma solidity ^0.8.12;

import { VerificationPackage } from "./interfaces/IPureFiVerifier.sol";


abstract contract ContextCompatible {
    function _saveVerificationPackage( VerificationPackage memory _verificationPackage ) internal virtual;
    function _removeVerificationPackage() internal virtual;
    function _getLocalVerificationPackage() internal view virtual returns ( VerificationPackage memory );
}