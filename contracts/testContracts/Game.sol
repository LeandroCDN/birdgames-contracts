// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {ITreasury} from "../../contracts/interfaces/ITreasury.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Game {
    ITreasury public treasury;

    

    function deposit(address token, uint256 amount) external {
        IERC20(token).approve(address(treasury), 99999 * 10 ** 19);
        treasury.depositTokens(token, amount);
    }

    function withdraw(address token, uint256 amount) external {
        treasury.withdrawTokens(token, amount, msg.sender);
    }

    function settreasury(ITreasury _treasury) public {

        treasury = _treasury;
    }
}