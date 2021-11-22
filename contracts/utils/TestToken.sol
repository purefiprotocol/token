// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

import "../../openzeppelin-contracts-master/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20{
    constructor(uint256 _supply, string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        _mint(_msgSender(), _supply);
    }
}