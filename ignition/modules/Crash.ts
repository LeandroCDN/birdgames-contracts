// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const CrashModule = buildModule("CrashModule", (m) => {
  
  const lock = m.contract("Crash");

  return { lock };
});

export default CrashModule;