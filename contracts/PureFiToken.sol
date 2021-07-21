// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../openzeppelin-contracts-master/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "../openzeppelin-contracts-master/contracts/access/AccessControl.sol";
import "./PureFiERC2771Context.sol";
import "./interfaces/IBotProtector.sol";

contract PureFiToken is ERC20Pausable, AccessControl, PureFiERC2771Context {

    address botProtector;

    constructor(address _admin, address _trustedForwarder) 
    ERC20("PureFi Token", "UFI") 
    PureFiERC2771Context(_trustedForwarder) {
        _mint(_admin, 100000000 * (10 ** uint(decimals())));
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Caller is not the Admin");
        _;
    }

    //admin functions
    function pause() onlyAdmin public {
        super._pause();
    }

    function unpause() onlyAdmin public {
        super._unpause();
    }

    function addForwarder(address trustedForwarder) onlyAdmin public{
        super._addForwarder(trustedForwarder);
    }

    function removeForwarder(address trustedForwarder) onlyAdmin public{
        super._removeForwarder(trustedForwarder);
    }

    function setBotProtector(address _botProtector) onlyAdmin public{
        botProtector = _botProtector;
    }

    //internal functions
    function _transfer(address sender, address recipient, uint256 amount) internal override {
        if(botProtector != address(0)){
            require(!IBotProtector(botProtector).isPotentialBotTransfer(sender, recipient), "PureFiToken: Bot transaction debounced");
        }
        super._transfer(sender, recipient, amount);
    }

    function _msgSender() internal override(Context, PureFiERC2771Context) view returns (address) {
        return PureFiERC2771Context._msgSender();
    }

    function _msgData() internal override(Context, PureFiERC2771Context) view returns (bytes calldata) {
        return PureFiERC2771Context._msgData();
    }
}