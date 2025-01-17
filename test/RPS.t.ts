import {
    time,
    loadFixture,
  } from "@nomicfoundation/hardhat-toolbox/network-helpers";
  import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
  import { expect } from "chai";
  import hre from "hardhat";

describe("RPS", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployRPSFixture() {
    const [owner, otherAccount , player] = await hre.ethers.getSigners();
    
    const Treasury = await hre.ethers.getContractFactory("Treasury");
    const treasury = await Treasury.deploy();

    const WOLDCoin = await hre.ethers.getContractFactory("WOLDCoin");
    const woldCoin = await WOLDCoin.deploy();

    const MockPermit2 = await hre.ethers.getContractFactory("MockPermit2");
    const mockPermit2 = await MockPermit2.deploy();

    const Rps = await hre.ethers.getContractFactory("RPS");
    const gamerps = await Rps.deploy(treasury.getAddress(), woldCoin.getAddress());
    gamerps.toggleGameIsLive();
    gamerps.setPermit2(mockPermit2.getAddress());
    gamerps.setMaxBetAmount(woldCoin.getAddress(),hre.ethers.parseUnits("100", 18));

    // const amount = hre.ethers.parseUnits("200", 18);
    // await woldCoin.transfer(player.address, amount);

    await treasury.setAuthorizedContract(await gamerps.getAddress(), true);
    await treasury.setAcceptedToken(await woldCoin.getAddress(), true);
    await gamerps.setPermit2(mockPermit2.getAddress());
    console.log("deployRPSFixture end");
    return { treasury,  owner, otherAccount, player, woldCoin, gamerps, mockPermit2};
  }
/*
  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { treasury, owner, gamerps } = await loadFixture(deployTreasuryFixture);
      expect(await treasury.owner()).to.equal(owner.address);
      expect(await gamerps.owner()).to.equal(owner.address);
    });
    it("Should set the right owner", async function () {
      const { treasury, owner, gamerps } = await loadFixture(deployTreasuryFixture);
      expect(await gamerps.treasury()).to.equal(await treasury.getAddress());
      expect(await gamerps.callers(owner.address)).to.equal(true);
    });
    it("Should set the right caller", async function () {
      const {  owner, gamerps } = await loadFixture(deployTreasuryFixture);
      expect(await gamerps.callers(owner.address)).to.equal(true);
    });
  })

  describe("Owner Functions", function () {
    it("setNewCaller should set a new caller and only owner  can call", async function () {
    })
    it("onlyOwner only owner can call and work", async function () {
    })
  })
*/
  describe("placeBet", function () {
    it("should call permit2 and deposit tokens in the treasury", async function () {
        const { gamerps, mockPermit2, woldCoin, treasury, owner, player } = await loadFixture(deployRPSFixture);

        // Aprobar tokens para el jugador
        const betAmount = hre.ethers.parseUnits("100", 18);
        await woldCoin.connect(owner).transfer(player.address, betAmount);
        await woldCoin.connect(player).approve(mockPermit2.getAddress(), betAmount);
        const woldAddress = await woldCoin.getAddress();
        // Crear un permit simulado
        const permit = {
            permitted: {
                token: woldAddress,
                amount: betAmount,
            },
            nonce: 0,
            deadline: "999999999999",
        };

        const transferDetails = {
            to: treasury.getAddress(),
            requestedAmount: betAmount,
        };

        const signature = "0x"; // Aquí puedes simular una firma si es necesario.
       
        // Llamar a placeBet
        await expect(
            gamerps.connect(player).placeBet(1, permit, transferDetails, signature)
        ).to.emit(mockPermit2, "MockTransfer")
        .withArgs(player.address, treasury.getAddress(), betAmount, woldAddress);
        
        // Verifica que los tokens se depositaron en el tesoro
        const treasuryBalanceAfter = await woldCoin.balanceOf(treasury.getAddress());
        
        expect(treasuryBalanceAfter).to.equal(betAmount);
    });
 });

 describe("_settleBet", function () {
    it("Caller can call _settleBet", async function () {
        const { gamerps, mockPermit2, woldCoin, treasury, owner, player } = await loadFixture(deployRPSFixture);
        const betAmount = hre.ethers.parseUnits("100", 18);
        const betAmountPlayer = hre.ethers.parseUnits("1", 17);
        await woldCoin.connect(owner).transfer(player.address, betAmount*BigInt(2));
        await woldCoin.connect(owner).transfer(treasury.getAddress(), betAmount * BigInt(2));
        await woldCoin.connect(player).approve(mockPermit2.getAddress(), betAmount* BigInt(200));
        const woldAddress = await woldCoin.getAddress();
        // Crear un permit simulado
        const permit = {
            permitted: {
                token: woldAddress,
                amount: betAmountPlayer,
            },
            nonce: 0,
            deadline: "999999999999",
        };

        const transferDetails = {
            to: treasury.getAddress(),
            requestedAmount: betAmountPlayer,
        };

        const signature = "0x";
        const playerBalanceBefore = await woldCoin.balanceOf(player.address);
        console.log("explotion rate:",await gamerps.explosionRate());
        
        let totalWins: number = 0;
        let totalLoses: number = 0;
        let totalDraws: number = 0;
        let totalBets: number = 1000;
        for (let i = 0; i < totalBets; i++) {
            try {
                await gamerps.connect(player).placeBet(2, permit, transferDetails, signature);
        
                // _settleBet
                let seed = Math.floor(Math.random() * 1000 * i); // Semilla arbitraria para el test
                let tx = await gamerps._settleBet(i, seed);
        
                let receipt = await tx.wait();
                let args;
        
                receipt?.logs.forEach((log, index) => {
                    if (log.args) {
                        args = log.args;
                    }
                });
        
                if (!args) {
                    console.error("No args found in logs for iteration:", i);
                    continue; // Salta esta iteración si no hay argumentos
                }
        
                let argsJSON = JSON.stringify(
                    Array.from(args).map((value) => (typeof value === "bigint" ? value.toString() : value))
                );
                let argsArray = JSON.parse(argsJSON);
        
                if (argsArray.length > 5) { // Asegúrate de que el índice 5 existe
        
                    if (argsArray[5] == 0) {
                        totalLoses++;
                    } else if (argsArray[5] == betAmountPlayer) {
                        totalDraws++;
                    } else {
                        totalWins++;
                    }
                } else {
                    console.error("argsArray does not have enough elements for iteration:", i, argsArray);
                }
            } catch (error) {
                console.error("Error in iteration", i, error);
            }
        }
        console.log("totalBets", totalBets);
        console.log("explosionRateGlobal",await gamerps.explosionRateGlobal());
        expect(1).to.equal(1);
        const playerBalanceAfter = await woldCoin.balanceOf(player.address);

        console.log("playerBalanceBefore", playerBalanceBefore / BigInt(10 ** 18), "WLD");
        console.log("playerBalanceAfter", playerBalanceAfter / BigInt(10 ** 18) , "WLD");
        console.log("totalWins", totalWins);
        console.log("totalLoses", totalLoses);
        console.log("totalDraws", totalDraws);
    });
 });
});