import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const AceFantasyModule = buildModule("AceFantasyModule", (m) => {
  const userPlayerManager = m.contract("UserPlayerManager", [], {});
  const leagueFactory = m.contract("LeagueFactory", [userPlayerManager], {});

  return { userPlayerManager, leagueFactory };
});

export default AceFantasyModule;
