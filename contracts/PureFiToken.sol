// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../openzeppelin-contracts-master/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "../openzeppelin-contracts-master/contracts/access/AccessControl.sol";
import "./interfaces/IBotProtector.sol";

contract PureFiToken is ERC20Pausable, AccessControl {

    address botProtector;

    constructor(address _admin) 
    ERC20("PureFi Token", "UFI") {
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
}