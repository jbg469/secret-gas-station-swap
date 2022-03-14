// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 supply
    ) public ERC20(name, symbol) {
        _mint(msg.sender, supply);
    }
}


contract ERC20MockWithDecimal is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 supply,
        uint8 decimals
    ) public ERC20(name, symbol) {
        _mint(msg.sender, supply);
        _setupDecimals(decimals);
    }
}