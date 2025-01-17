// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const TreasuryModule = buildModule("TreasuryModule", (m) => {
  const treasury = m.contract("Treasury");

  return { treasury };
});

export default TreasuryModule;
