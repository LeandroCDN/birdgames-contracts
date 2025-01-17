// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../interfaces/ISignatureTransfer.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract MockPermit2  {
    event MockTransfer(address indexed from, address indexed to, uint256 amount, address token);
    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }
    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address sender,
        bytes calldata signature
    ) external  {
        // Simula la transferencia y emite un evento para validación en los tests.
        require(permit.permitted.amount > 0, "Mock: Invalid transfer amount");
        IERC20(permit.permitted.token).transferFrom(sender, transferDetails.to, transferDetails.requestedAmount);
        emit MockTransfer(sender, transferDetails.to, permit.permitted.amount, permit.permitted.token);
    }
}