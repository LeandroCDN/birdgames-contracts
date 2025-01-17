// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract WOLDCoin is ERC20, ERC20Permit {
    constructor() ERC20("WOLD", "MTK") ERC20Permit("WOLD") {
        _mint(msg.sender, 1500000 * 10 ** decimals());
    }
}