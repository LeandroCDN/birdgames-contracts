import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
const { vars } = require("hardhat/config");

const PRIVATE_KEY = vars.get("DEPLOY_WALLET_KEY");
// const ETHERSCAN_API_KEY = vars.get("ETHERSCAN_API_KEY");
const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    world: {
      url: `https://worldchain-mainnet.gateway.tenderly.co`,
      accounts: [PRIVATE_KEY],
    },
  },
  sourcify: {
    enabled: true,
  },
  etherscan: {
    // apiKey: ETHERSCAN_API_KEY,
    customChains: [
      {
        network: "world",
        chainId: 480,
        urls: {
          apiURL: "https://api.worldscan.org/api",
          browserURL: "https://worldscan.org/",
        },
      },
    ],
  },
};

export default config;
