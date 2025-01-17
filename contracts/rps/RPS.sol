// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ManagerRPS, IERC20} from "./ManagerRPS.sol";
import {ISignatureTransfer} from "../interfaces/ISignatureTransfer.sol";
import {ITreasury} from "../interfaces/ITreasury.sol";
import "hardhat/console.sol";

contract RPS is ManagerRPS {
    uint256 public explosionRate = 3;
    ISignatureTransfer public permit2 = ISignatureTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    ITreasury public treasury;

    struct Player {
        uint32 totalBets;
        uint32 totalWins;
        uint256 totalValue;
        uint256 points;
        uint256[] betIds;
    }

    uint256 public totalBetsGlobal;
    uint256 public totalGlobalWins;
    uint256 public totalValueGlobal;
    uint256 public totalValueGlobalIn;
    uint256 public explosionRateGlobal;

    mapping(address => bool) public callers;
    mapping(address => uint256) public pendingIdsPerPlayer;
    mapping(address => Player) public playerInfo;

    constructor(address _treasury, address token) ManagerRPS(msg.sender) {
        callers[msg.sender] = true;
        treasury = ITreasury(_treasury);
        IERC20(token).approve(address(treasury), 99999999 * 10 ** 19);
    }

    modifier onlyCaller() {
        require(callers[msg.sender], "Caller is not authorized");
        _;
    }

    function setNewCaller(address newCaller) external onlyOwner {
        callers[newCaller] = true;
    }

    function placeBet(
        uint8 side,
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails calldata transferDetails,
        bytes calldata signature
    ) external {
        require(side == 0 || side == 1 || side == 2, "Invalid side");

        address token = permit.permitted.token;
        uint256 amount = permit.permitted.amount;

        address player = msg.sender;
        require(gameIsLive, "Game is not live");
        require(token != address(0), "Token address cannot be 0");
        require(
            amount >= supportedTokenInfo[token].minBetAmount && amount <= supportedTokenInfo[token].maxBetAmount,
            "Bet amount not within range"
        );
        require(pendingIdsPerPlayer[player] == 0, "You have a pending bet");

        permit2.permitTransferFrom(permit, transferDetails, msg.sender, signature);
        treasury.depositTokens(token, amount);

        uint256 betId = bets.length;
        playerInfo[player].totalBets++;
        playerInfo[player].totalValue += amount;
        playerInfo[player].points += 1 * 200 - 1;
        playerInfo[player].betIds.push(betId + 1);
        pendingIdsPerPlayer[player] = betId;
        totalValueGlobalIn += amount;

        emit BetPlaced(betId, player, amount, side, token);
        bets.push(
            Bet({
                choice: side,
                outcome: 0,
                isDraw: false,
                placeBlockNumber: uint176(block.number),
                amount: uint128(amount),
                winAmount: 0,
                player: player,
                token: token,
                isSettled: false
            })
        );
    }

    function _settleBet(uint256 betId, uint256 seed) external onlyCaller {
        Bet storage bet = bets[betId];

        if (bet.amount == 0 || bet.isSettled == true) {
            return;
        }

        // Calculate outcome first
        uint256 randomNumber =
            uint256(keccak256(abi.encode(seed, block.timestamp, block.prevrandao, blockhash(bet.placeBlockNumber))));

        // Handle explosion case
        uint256 exploted = randomNumber % 100;
        if (exploted <= explosionRate) {
            explosionRateGlobal++;
            _handleExplosion(bet, betId);
            return;
        }
        uint256 optionOutcome = randomNumber % 3;

        bool isDraw = bet.choice == optionOutcome;
        bool winResult;

        if (!isDraw) {
            totalValueGlobal += bet.amount;
            if (
                (bet.choice == 0 && optionOutcome == 2) // Piedra vence Tijera
                    || (bet.choice == 1 && optionOutcome == 0) // Papel vence Piedra
                    || (bet.choice == 2 && optionOutcome == 1) // Tijera vence Papel
            ) {
                winResult = true;
            } else {
                winResult = false;
            }
        } else {
            winResult = false;
            bet.isDraw = true;
            optionOutcome = 3;
        }

        _finalizeSettlement(bet, betId, winResult, optionOutcome);
    }

    function _handleExplosion(Bet storage bet, uint256 betId) private {
        pendingIdsPerPlayer[bet.player] = 0;
        bet.isSettled = true;
        bet.winAmount = uint128(0);
        uint256 userChoice = bet.choice;
        uint8 optionOutcome;
        if (userChoice == 0) {
            optionOutcome = 1;
        } else if (userChoice == 1) {
            optionOutcome = 2;
        } else {
            optionOutcome = 0;
        }

        bet.outcome = optionOutcome;

        emit BetSettled(betId, bet.player, bet.amount, bet.choice, optionOutcome, 0, bet.token);
    }

    function _finalizeSettlement(Bet storage bet, uint256 betId, bool winResult, uint256 outcome) private {
        uint256 winnableAmount = bet.amount * 2;
        uint256 winAmount = winResult ? winnableAmount : 0;

        pendingIdsPerPlayer[bet.player] = 0;
        bet.isSettled = true;
        bet.winAmount = uint128(winAmount);
        bet.outcome = uint8(outcome);

        if (winAmount > 0) {
            totalGlobalWins++;
            playerInfo[bet.player].totalWins++;
            treasury.withdrawTokens(bet.token, winnableAmount, bet.player);
        }
        if (outcome == 3) {
            treasury.withdrawTokens(bet.token, bet.amount, bet.player);
            winAmount = bet.amount;
        }

        emit BetSettled(betId, bet.player, bet.amount, bet.choice, uint8(outcome), winAmount, bet.token);
    }

    function refundBet(uint256 betId) external onlyOwner {
        require(gameIsLive, "Game is not live");
        Bet storage bet = bets[betId];
        uint256 amount = bet.amount;

        require(amount > 0, "Bet does not exist");
        require(bet.isSettled == false, "Bet is settled already");
        require(block.number > bet.placeBlockNumber + 21600, "Wait before requesting refund");

        address token = bet.token;
        uint256 bettedAmount = amountToBettableAmountConverter(amount, token);

        bet.isSettled = true;
        bet.winAmount = uint128(bettedAmount);

        treasury.withdrawTokens(bet.token, bettedAmount, bet.player);
        pendingIdsPerPlayer[bet.player] = 0;
        emit BetRefunded(betId, bet.player, bettedAmount, token);
    }

    function setExplosionRate(uint256 _explosionRate) external onlyOwner {
        explosionRate = _explosionRate;
    }

    function getPlayerInfo(address player) external view returns (uint256, uint256, uint256) {
        return (playerInfo[player].totalBets, playerInfo[player].totalValue, playerInfo[player].points);
    }

    function getPlayerBets(address player) external view returns (uint256[] memory) {
        return playerInfo[player].betIds;
    }

    function getLastBets(uint256 amount, bool fullList) external view returns (Bet[] memory) {
        if (fullList) {
            return bets;
        }
        Bet[] memory betOutcomes = new Bet[](amount);
        for (uint256 i = bets.length - 1; i > bets.length - amount; i--) {
            Bet storage bet = bets[i];
            betOutcomes[i] = bet;
        }
        return betOutcomes;
    }

    function getAverangeAmount() external view returns (uint256) {
        return totalValueGlobalIn / bets.length;
    }

    function setTreasury(ITreasury _treasury) public onlyOwner {
        treasury = _treasury;
    }

    function setApproveTreasury(address token, uint256 amout) public onlyOwner {
        IERC20(token).approve(address(treasury), amout);
    }

    function setPermit2(ISignatureTransfer _permit2) public onlyOwner {
        permit2 = _permit2;
    }
}
