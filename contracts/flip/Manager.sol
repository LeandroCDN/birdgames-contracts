// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Manager is Ownable {
    bool public gameIsLive;
    uint256 public minMultiplier = 100;
    uint256 public maxMultiplier = 10000;

    struct Token {
        uint128 minBetAmount;
        uint128 maxBetAmount;
        uint256 houseEdgeBP;
    }

    struct Bet {
        bool choice;
        bool winResult;
        uint176 placeBlockNumber;
        uint128 amount;
        uint128 winAmount;
        address player;
        address token;
        bool isSettled;
    }

    Bet[] public bets;
    mapping(address => Token) public supportedTokenInfo;
    mapping(bytes32 => uint256[]) public betMap;

    //events
    event BetPlaced(uint256 indexed betId, address indexed player, uint256 amount, bool choice, address token);
    event BetSettled(
        uint256 indexed betId,
        address indexed player,
        uint256 amount,
        bool choice,
        bool outcome,
        uint256 winAmount,
        address token
    );
    event BetRefunded(uint256 indexed betId, address indexed player, uint256 amount, address token);

    constructor(address initialOwner) Ownable(msg.sender) {}

    function betsLength() external view returns (uint256) {
        return bets.length;
    }

    function setMinMultiplier(uint256 _minMultiplier) external onlyOwner {
        minMultiplier = _minMultiplier;
    }

    function setMaxMultiplier(uint256 _maxMultiplier) external onlyOwner {
        maxMultiplier = _maxMultiplier;
    }

    function setMinBetAmount(address token, uint128 _minBetAmount) external onlyOwner {
        require(_minBetAmount < supportedTokenInfo[token].maxBetAmount, "Min amount must be less than max amount");
        supportedTokenInfo[token].minBetAmount = _minBetAmount;
    }

    function setMaxBetAmount(address token, uint128 _maxBetAmount) external onlyOwner {
        require(_maxBetAmount > supportedTokenInfo[token].minBetAmount, "Max amount must be greater than min amount");
        supportedTokenInfo[token].maxBetAmount = _maxBetAmount;
    }

    function setHouseEdgeBP(address token, uint256 _houseEdgeBP) external onlyOwner {
        require(gameIsLive == false, "Bets in pending");
        supportedTokenInfo[token].houseEdgeBP = _houseEdgeBP;
    }

    function toggleGameIsLive() external onlyOwner {
        gameIsLive = !gameIsLive;
    }

    function amountToBettableAmountConverter(uint256 amount, address token) internal view returns (uint256) {
        return amount * (10000 - supportedTokenInfo[token].houseEdgeBP) / 10000;
    }

    function amountToWinnableAmount(uint256 _amount, uint256 multiplier, address token)
        internal
        view
        returns (uint256)
    {
        uint256 bettableAmount = amountToBettableAmountConverter(_amount, token);
        return bettableAmount * multiplier / 100;
    }

    // withdraw any token from contract
    function withdrawCustomTokenFunds(address beneficiary, uint256 withdrawAmount, address token) external onlyOwner {
        require(withdrawAmount <= IERC20(token).balanceOf(address(this)), "Withdrawal exceeds limit");
        IERC20(token).transfer(beneficiary, withdrawAmount);
    }
}