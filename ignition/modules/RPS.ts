// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const RPSModule = buildModule("RPSModule", (m) => {
  const treasuryAddress = "0xf56F5D348ad4bc29e0885550250Cb1B1a919834c";
  const wldAddress = "0x2cFc85d8E48F8EAB294be644d9E25C3030863003";
  const rps = m.contract("RPS", [treasuryAddress, wldAddress]);

  return { rps };
});

export default RPSModule;
