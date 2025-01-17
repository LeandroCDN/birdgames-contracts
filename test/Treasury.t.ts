import {
    time,
    loadFixture,
  } from "@nomicfoundation/hardhat-toolbox/network-helpers";
  import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
  import { expect } from "chai";
  import hre from "hardhat";

describe("Treasury", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployTreasuryFixture() {
    const [owner, otherAccount , player] = await hre.ethers.getSigners();
    
    const Treasury = await hre.ethers.getContractFactory("Treasury");
    const treasury = await Treasury.deploy();

    const WOLDCoin = await hre.ethers.getContractFactory("WOLDCoin");
    const woldCoin = await WOLDCoin.deploy();

    const Game = await hre.ethers.getContractFactory("Game");
    const game = await Game.deploy();

    game.settreasury(treasury.getAddress());

    return { treasury,  owner, otherAccount, player, woldCoin, game};
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { treasury, owner } = await loadFixture(deployTreasuryFixture);
      expect(await treasury.owner()).to.equal(owner.address);
    });

  });

  describe("Authorization", function () {
    it("Should allow the owner to authorize a game contract", async function () {
      const { treasury, game } = await loadFixture(deployTreasuryFixture);
  
      await expect(treasury.setAuthorizedContract(game.getAddress(), true))
        .to.emit(treasury, "ContractAuthorized")
        .withArgs(game.getAddress(), true);
  
      expect(await treasury.authorizedContracts(game.getAddress())).to.be.true;
    });

    it("Should allow the owner to set accepted tokens", async function () {
      const { treasury, owner, woldCoin } = await loadFixture(deployTreasuryFixture);
  
      await expect(treasury.setAcceptedToken(woldCoin.getAddress(), true))
        .to.emit(treasury, "TokenAccepted")
        .withArgs(woldCoin.getAddress(), true);
  
      expect(await treasury.acceptedTokens(woldCoin.getAddress())).to.be.true;
    });
  });

  describe("Deposits", function () {
    it("Should allow authorized contracts to deposit accepted tokens", async function () {
      const { treasury, owner, woldCoin, game } = await loadFixture(deployTreasuryFixture);
  
      await treasury.setAuthorizedContract(await game.getAddress(), true);
      await treasury.setAcceptedToken(await woldCoin.getAddress(), true);
      const amount = hre.ethers.parseUnits("1000", 18);
      await woldCoin.transfer(game.getAddress(), amount);
      
      await expect(game.deposit(woldCoin.getAddress(), amount))
        .to.emit(treasury, "TokensDeposited")
        .withArgs(game.getAddress(), woldCoin.getAddress(), amount);
  
      const stats = await treasury.gameStats(game.getAddress(), woldCoin.getAddress());
      expect(stats.totalDeposits).to.equal(amount);
    });
  
    it("Should reject deposits from unauthorized contracts", async function () {
      const { treasury, otherAccount, woldCoin } = await loadFixture(deployTreasuryFixture);
  
      await treasury.setAcceptedToken(woldCoin.getAddress(), true);
      const amount = hre.ethers.parseUnits("100", 18);
  
      await expect(
        treasury.connect(otherAccount).depositTokens(woldCoin.getAddress(), amount)
      ).to.be.revertedWith("Not an authorized contract");
    });
  });

  describe("Withdrawals", function () {
    it("Should allow authorized contracts to withdraw tokens", async function () {
      const { treasury, owner, woldCoin, game, player } = await loadFixture(deployTreasuryFixture);
  
      await treasury.setAuthorizedContract(game.getAddress(), true);
      await treasury.setAcceptedToken(woldCoin.getAddress(), true);
  
      const amount = hre.ethers.parseUnits("100", 18);
      await woldCoin.transfer(game.getAddress(), amount);
  
      await game.deposit(woldCoin.getAddress(), amount);
  
      await expect(game.connect(player).withdraw(woldCoin.getAddress(), amount))
        .to.emit(treasury, "TokensWithdrawn")
        .withArgs(game.getAddress(), player.address, woldCoin.getAddress(), amount);
  
      const stats = await treasury.gameStats(game.getAddress(), woldCoin.getAddress());
      expect(stats.totalWithdrawals).to.equal(amount);
    });
  
    it("Should reject withdrawals from unauthorized contracts", async function () {
      const { treasury, otherAccount, woldCoin, player } = await loadFixture(deployTreasuryFixture);
  
      await treasury.setAcceptedToken(woldCoin.getAddress(), true);
      const amount = hre.ethers.parseUnits("100", 18);
  
      await expect(
        treasury.connect(otherAccount).withdrawTokens(woldCoin.getAddress(), amount, player.address)
      ).to.be.revertedWith("Not an authorized contract");
    });
  });

  describe("Emergency Withdraw", function () {
    it("Should allow the owner to perform an emergency withdraw", async function () {
      const { treasury, owner, woldCoin, player, game } = await loadFixture(deployTreasuryFixture);
      
      await treasury.setAuthorizedContract(game.getAddress(), true);
      await treasury.setAcceptedToken(woldCoin.getAddress(), true);

      const amount = hre.ethers.parseUnits("50", 18);
      await woldCoin.transfer(treasury.getAddress(), amount);
  
      await expect(treasury.emergencyWithdraw(woldCoin.getAddress(), amount, player.address))
        .to.emit(woldCoin, "Transfer")
        .withArgs(treasury.getAddress(), player.address, amount);
    });
  });
});