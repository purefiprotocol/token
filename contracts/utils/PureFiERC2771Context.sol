// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../openzeppelin-contracts-master/contracts/utils/Context.sol";

/*
 * @dev Context variant with ERC2771 support. Derived from OpenZeppelin ERC2771Context
 */
abstract contract PureFiERC2771Context is Context {

    mapping (address => bool) trustedForwarders;

    event TrustedForwarderAdded(address forwarder);
    event TrustedForwarderRemoved(address forwarder);

    constructor(address trustedForwarder) {
        trustedForwarders[trustedForwarder] = true;
    }

    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return trustedForwarders[forwarder];
    }

    function _msgSender() internal view virtual override returns (address sender) {
        if (isTrustedForwarder(msg.sender)) {
            // The assembly code is more direct than the Solidity version using `abi.decode`.
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return super._msgSender();
        }
    }

    function _msgData() internal view virtual override returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }

    function _addForwarder(address trustedForwarder) internal {
        trustedForwarders[trustedForwarder] = true;
        emit TrustedForwarderAdded(trustedForwarder);
    }

    function _removeForwarder(address trustedForwarder) internal {
        delete trustedForwarders[trustedForwarder];
        emit TrustedForwarderRemoved(trustedForwarder);
    }

}
