// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const FlipModule = buildModule("FlipModule", (m) => {
  const lock = m.contract("Flip");

  return { lock };
});

export default FlipModule;