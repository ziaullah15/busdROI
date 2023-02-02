// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ZiaToken is ERC20 {
    constructor() ERC20("ZIA", "ZZZ") {
        _mint(msg.sender, 1000000000000000000000000000000000000000*10**6);
    }
}