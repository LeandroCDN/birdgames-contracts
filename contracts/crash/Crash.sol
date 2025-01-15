// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ManagerCrash, IERC20} from "./ManagerCrash.sol";
import {ISignatureTransfer} from "../interfaces/ISignatureTransfer.sol";
import {ITreasury} from "../interfaces/ITreasury.sol";

contract Crash is ManagerCrash {
    uint256 public explosionRate = 1;
    ISignatureTransfer public permit2 = ISignatureTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    ITreasury public treasury;

    struct Player {
        uint32 totalBets;
        uint256 totalValue;
        uint256 points;
        uint256[] betIds;
    }

    uint256 totalBetsGlobal;
    uint256 totalValueGlobal;

    mapping(address => bool) public callers;
    mapping(address => uint256) public pendingIdsPerPlayer;
    mapping(address => Player) public playerInfo;

    constructor() ManagerCrash(msg.sender) {
        callers[msg.sender] = true;
    }

    modifier onlyCaller() {
        require(callers[msg.sender], "Caller is not authorized");
        _;
    }

    function placeBet(
        uint256 multiplierChoice,
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails calldata transferDetails,
        bytes calldata signature
    ) external {
        address token = permit.permitted.token;
        uint256 amount = permit.permitted.amount;
        address player = msg.sender;
        require(gameIsLive, "Game is not live");
        require(minMultiplier < multiplierChoice && multiplierChoice <= maxMultiplier, "Bet mask not in range");
        require(token != address(0), "Token address cannot be 0");
        require(
            amount >= supportedTokenInfo[token].minBetAmount && amount <= supportedTokenInfo[token].maxBetAmount,
            "Bet amount not within range"
        );
        require(pendingIdsPerPlayer[player] == 0, "You have a pending bet");
        // uint winnableAmount = amountToWinnableAmount(amount, multiplierChoice, token);

        // permit2 signature transger
        // house.placeBet{value: msg.value}(player, amount, token, winnableAmount);
        permit2.permitTransferFrom(permit, transferDetails, msg.sender, signature);
        treasury.depositTokens(token, amount);
        uint256 betId = bets.length + 1;

        playerInfo[player].totalBets++;
        playerInfo[player].totalValue += amount;
        playerInfo[player].points += 1 * multiplierChoice - 1;
        playerInfo[player].betIds.push(betId);
        // es sistema para manejar varias resoluciones
        // betMap[VRFManager.sendRequestRandomness()].push(betId);
        pendingIdsPerPlayer[player] = betId;
        emit BetPlaced(betId, player, amount, multiplierChoice, token);
        bets.push(
            Bet({
                choice: uint40(multiplierChoice),
                outcome: 0,
                placeBlockNumber: uint176(block.number),
                amount: uint128(amount),
                winAmount: 0,
                player: player,
                token: token,
                isSettled: false
            })
        );
    }

    function _settleBet(uint256 betId, uint256 seed) external onlyCaller returns (uint256, uint256, uint256) {
        Bet storage bet = bets[betId];

        if (bet.amount == 0 || bet.isSettled == true) {
            return (0, 0, 0);
        }

        // Calculate outcome first
        uint256 randomNumber =
            uint256(keccak256(abi.encode(seed, block.timestamp, block.prevrandao, blockhash(bet.placeBlockNumber))));

        // Handle explosion case
        uint256 exploted = randomNumber % 100;
        if (exploted <= explosionRate) {
            _handleExplosion(bet, betId);
            return (bet.choice, 0, 0);
        }

        // Calculate multiplier outcome
        uint256 H = randomNumber % (maxMultiplier - minMultiplier + 1);
        uint256 E = maxMultiplier / 100;
        uint256 multiplierOutcome = (E * maxMultiplier - H) / (E * 100 - H);

        // Handle win/loss
        totalBetsGlobal++;
        totalValueGlobal += bet.amount;
        return _finalizeSettlement(bet, betId, multiplierOutcome);
    }

    function _handleExplosion(Bet storage bet, uint256 betId) private {
        pendingIdsPerPlayer[bet.player] = 0;
        bet.isSettled = true;
        bet.winAmount = uint128(0);
        bet.outcome = uint40(0);

        emit BetSettled(betId, bet.player, bet.amount, bet.choice, 0, 0, bet.token);
    }

    function _finalizeSettlement(Bet storage bet, uint256 betId, uint256 multiplierOutcome)
        private
        returns (uint256, uint256, uint256)
    {
        uint256 winnableAmount = amountToWinnableAmount(bet.amount, bet.choice, bet.token);
        uint256 winAmount = bet.choice <= multiplierOutcome ? winnableAmount : 0;

        pendingIdsPerPlayer[bet.player] = 0;
        bet.isSettled = true;
        bet.winAmount = uint128(winAmount);
        bet.outcome = uint40(multiplierOutcome);

        if (winAmount > 0) {
            treasury.withdrawTokens(bet.token, winnableAmount, bet.player);
        }

        emit BetSettled(betId, bet.player, bet.amount, bet.choice, multiplierOutcome, winAmount, bet.token);

        return (bet.choice, multiplierOutcome, winAmount);
    }

    function refundBet(uint256 betId) external onlyOwner {
        require(gameIsLive, "Game is not live");
        Bet storage bet = bets[betId];
        uint256 amount = bet.amount;

        require(amount > 0, "Bet does not exist");
        require(bet.isSettled == false, "Bet is settled already");
        require(block.number > bet.placeBlockNumber + 21600, "Wait before requesting refund");

        address token = bet.token;
        uint256 winnableAmount = amountToWinnableAmount(amount, bet.choice, token);
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

    function playFree(uint256 multiplier) external view returns (uint256, bool) {
        uint256 randomNumber =
            uint256(keccak256(abi.encode(block.timestamp, block.prevrandao, blockhash(block.number - 1))));

        uint256 H = randomNumber % (maxMultiplier - minMultiplier + 1);
        uint256 E = maxMultiplier / 100;
        uint256 multiplierOutcome = (E * maxMultiplier - H) / (E * 100 - H);

        return (multiplierOutcome, multiplier <= multiplierOutcome);
    }

    function getPlayerInfo(address player) external view returns (uint256, uint256, uint256) {
        return (playerInfo[player].totalBets, playerInfo[player].totalValue, playerInfo[player].points);
    }

    function getPlayerBets(address player) external view returns (uint256[] memory) {
        return playerInfo[player].betIds;
    }

    function getSeveralBets(uint256[] memory betIds, bool fullList) external view returns (Bet[] memory) {
        if (fullList) {
            return bets;
        }
        uint256 l = betIds.length;
        Bet[] memory betOutcomes = new Bet[](l);
        for (uint256 i = 0; i < betIds.length; i++) {
            Bet storage bet = bets[betIds[i]];
            betOutcomes[i] = bet;
        }
        return betOutcomes;
    }

    function getAverangeMultiplier() external view returns (uint256) {
        uint256 totalMultiplier;
        for (uint256 i = 0; i < bets.length; i++) {
            totalMultiplier += bets[i].choice;
        }
        return totalMultiplier / totalBetsGlobal;
    }
}