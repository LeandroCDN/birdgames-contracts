// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Manager, IERC20} from "./Manager.sol";
import {ISignatureTransfer} from "../interfaces/ISignatureTransfer.sol";
import {ITreasury} from "../interfaces/ITreasury.sol";

contract Flip is Manager {
    uint256 public explosionRate = 1;
    ISignatureTransfer public permit2 = ISignatureTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    ITreasury public treasury;


    struct Player {
        uint32 totalBets;
        uint32 totalGoals;
        uint256 totalValue;
        uint256 points;
        uint256[] betIds;
    }

    uint256 totalBetsGlobal;
    uint256 totalGlobalGoals;
    uint256 totalValueGlobal;

    mapping(address => bool) public callers;
    mapping(address => uint256) public pendingIdsPerPlayer;
    mapping(address => Player) public playerInfo;

    constructor() Manager(msg.sender) {
        callers[msg.sender] = true;
    }

    modifier onlyCaller() {
        require(callers[msg.sender], "Caller is not authorized");
        _;
    }

    function placeBet(
        bool side,
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails calldata transferDetails,
        bytes calldata signature
    ) external {
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
        uint256 betId = bets.length + 1;
        playerInfo[player].totalBets++;
        playerInfo[player].totalValue += amount;
        playerInfo[player].points += 1 * 200 - 1;

        playerInfo[player].betIds.push(betId);
        // es sistema para manejar varias resoluciones
        // betMap[VRFManager.sendRequestRandomness()].push(betId);
        pendingIdsPerPlayer[player] = betId;
        emit BetPlaced(betId, player, amount, side, token);
        bets.push(
            Bet({
                choice: side,
                winResult: false,
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
            _handleExplosion(bet, betId);
            return;
        }
        bool result = (randomNumber % (100) < 50) ? true : false; // true left, false right
        bool winResult = bet.choice == result ? false : true; // true win, false lose

        // Handle win/loss
        totalBetsGlobal++;
        totalValueGlobal += bet.amount;
        _finalizeSettlement(bet, betId, winResult);
    }

    function _handleExplosion(Bet storage bet, uint256 betId) private {
        pendingIdsPerPlayer[bet.player] = 0;
        bet.isSettled = true;
        bet.winAmount = uint128(0);
        bet.winResult = bet.choice ? false : true;

        emit BetSettled(betId, bet.player, bet.amount, bet.choice, bet.winResult, 0, bet.token);
    }

    function _finalizeSettlement(Bet storage bet, uint256 betId, bool winResult)
        private
        returns (bool, bool, uint256)
    {
        uint256 winnableAmount = bet.amount * 2;
        uint256 winAmount = winResult ? winnableAmount : 0;

        pendingIdsPerPlayer[bet.player] = 0;
        bet.isSettled = true;
        bet.winAmount = uint128(winAmount);
        bet.winResult = winResult;

        if (winAmount > 0) {
            totalGlobalGoals++;
            playerInfo[bet.player].totalGoals++;
            treasury.withdrawTokens(bet.token, winnableAmount, bet.player);
        }

        emit BetSettled(betId, bet.player, bet.amount, bet.choice, winResult, winAmount, bet.token);

        return (bet.choice, winResult, winAmount);
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

    function getLastBets(uint256 amount, bool fullList) external view returns (Bet[] memory) {
        if (fullList) {
            return bets;
        }
        Bet[] memory betOutcomes = new Bet[](amount);
        for (uint256 i = totalBetsGlobal - 1; i > totalBetsGlobal - amount; i--) {
            Bet storage bet = bets[i];
            betOutcomes[i] = bet;
        }
        return betOutcomes;
    }
}