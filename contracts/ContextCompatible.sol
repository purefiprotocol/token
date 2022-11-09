// SPDX-License-Identifier: GPL-2.0-or-later


pragma solidity ^0.8.12;

import { VerificationData } from "./interfaces/IPureFiVerifier.sol";

abstract contract ContextCompatible {
    function _saveVerificationData( VerificationData memory data ) internal virtual;
    function _removeVerificationData() internal virtual;
    function _getLocalVerificationData() internal view virtual returns ( VerificationData memory );
}