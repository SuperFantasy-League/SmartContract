import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("AceFantasy", function () {
  // Fixture to deploy all contracts
  async function deployContractsFixture() {
    const [owner, admin, user1, user2] = await hre.ethers.getSigners();

    // Deploy PlayerCard contract
    const PlayerCard = await hre.ethers.getContractFactory("PlayerCard");
    const playerCard = await PlayerCard.deploy();

    // Deploy Factories
    const LeagueFactory = await hre.ethers.getContractFactory("LeagueFactory");
    const leagueFactory = await LeagueFactory.deploy(await playerCard.getAddress());

    const TournamentFactory = await hre.ethers.getContractFactory("TournamentFactory");
    const tournamentFactory = await TournamentFactory.deploy();

    // Constants for testing
    const WEEK_IN_SECS = 7 * 24 * 60 * 60;
    const currentTime = await time.latest();
    const leagueStartTime = currentTime + WEEK_IN_SECS;
    const leagueEndTime = leagueStartTime + WEEK_IN_SECS;
    const entryFee = hre.ethers.parseEther("0.1");
    const maxTeams = 10;

    return {
      playerCard,
      leagueFactory,
      tournamentFactory,
      owner,
      admin,
      user1,
      user2,
      currentTime,
      leagueStartTime,
      leagueEndTime,
      entryFee,
      maxTeams,
    };
  }

  describe("PlayerCard", function () {
    describe("Deployment", function () {
      it("Should set the right owner", async function () {
        const { playerCard, owner } = await loadFixture(deployContractsFixture);

        expect(await playerCard.hasRole(await playerCard.DEFAULT_ADMIN_ROLE(), owner.address))
          .to.be.true;
      });

      it("Should grant MINTER_ROLE to owner", async function () {
        const { playerCard, owner } = await loadFixture(deployContractsFixture);

        expect(await playerCard.hasRole(await playerCard.MINTER_ROLE(), owner.address))
          .to.be.true;
      });
    });

    describe("Minting", function () {
      it("Should mint a new player card", async function () {
        const { playerCard, user1 } = await loadFixture(deployContractsFixture);

        await playerCard.mintPlayer(
          user1.address,
          "Test Player",
          1, // GK position
          1, // Team ID
          1000 // Initial value
        );

        expect(await playerCard.ownerOf(1)).to.equal(user1.address);
      });

      it("Should fail if non-minter tries to mint", async function () {
        const { playerCard, user1 } = await loadFixture(deployContractsFixture);

        await expect(
          playerCard.connect(user1).mintPlayer(
            user1.address,
            "Test Player",
            1,
            1,
            1000
          )
        ).to.be.reverted;
      });

      it("Should update player points correctly", async function () {
        const { playerCard, user1 } = await loadFixture(deployContractsFixture);

        await playerCard.mintPlayer(user1.address, "Test Player", 1, 1, 1000);
        await playerCard.updatePlayerPoints(1, 10);

        const player = await playerCard.players(1);
        expect(player.points).to.equal(10);
      });
    });
  });

  describe("LeagueFactory", function () {
    describe("League Creation", function () {
      it("Should create a new league", async function () {
        const { leagueFactory, leagueStartTime, leagueEndTime, entryFee, maxTeams } =
          await loadFixture(deployContractsFixture);

        await expect(
          leagueFactory.createLeague(
            "Test League",
            entryFee,
            maxTeams,
            leagueStartTime,
            leagueEndTime
          )
        ).to.emit(leagueFactory, "LeagueCreated");
      });

      it("Should fail if end time is before start time", async function () {
        const { leagueFactory, currentTime, entryFee, maxTeams } =
          await loadFixture(deployContractsFixture);

        await expect(
          leagueFactory.createLeague(
            "Test League",
            entryFee,
            maxTeams,
            currentTime + 1000,
            currentTime + 500 // End time before start time
          )
        ).to.be.revertedWith("Invalid end time");
      });
    });
  });

  describe("League", function () {
    async function deployLeagueFixture() {
      const baseFixture = await deployContractsFixture();

      // Create a league
      const tx = await baseFixture.leagueFactory.createLeague(
        "Test League",
        baseFixture.entryFee,
        baseFixture.maxTeams,
        baseFixture.leagueStartTime,
        baseFixture.leagueEndTime
      );
      const receipt = await tx.wait();
      const event = receipt?.logs[0];
      const leagueAddress = event?.args?.leagueAddress;

      const League = await hre.ethers.getContractFactory("League");
      const league = League.attach(leagueAddress);

      return {
        ...baseFixture,
        league,
      };
    }

    describe("Team Registration", function () {
      it("Should register a team with correct entry fee", async function () {
        const { league, playerCard, user1, entryFee } = await loadFixture(
          deployLeagueFixture
        );

        // Mint player cards for the team
        const playerIds = [];
        for (let i = 0; i < 11; i++) {
          await playerCard.mintPlayer(user1.address, `Player ${i}`, 1, 1, 1000);
          playerIds.push(i + 1);
        }

        await expect(
          league.connect(user1).registerTeam(playerIds, { value: entryFee })
        ).to.emit(league, "TeamRegistered");
      });

      it("Should fail with incorrect entry fee", async function () {
        const { league, playerCard, user1 } = await loadFixture(
          deployLeagueFixture
        );

        const playerIds = [];
        for (let i = 0; i < 11; i++) {
          await playerCard.mintPlayer(user1.address, `Player ${i}`, 1, 1, 1000);
          playerIds.push(i + 1);
        }

        await expect(
          league.connect(user1).registerTeam(playerIds, { value: 0 })
        ).to.be.revertedWith("Incorrect entry fee");
      });
    });
  });

  describe("TournamentFactory", function () {
    describe("Tournament Creation", function () {
      it("Should create a new tournament", async function () {
        const { tournamentFactory, leagueStartTime, leagueEndTime } =
          await loadFixture(deployContractsFixture);

        await expect(
          tournamentFactory.createTournament(
            "Test Tournament",
            leagueStartTime,
            leagueEndTime
          )
        ).to.emit(tournamentFactory, "TournamentCreated");
      });
    });
  });

  describe("Tournament", function () {
    async function deployTournamentFixture() {
      const baseFixture = await deployContractsFixture();

      // Create a tournament
      const tx = await baseFixture.tournamentFactory.createTournament(
        "Test Tournament",
        baseFixture.leagueStartTime,
        baseFixture.leagueEndTime
      );
      const receipt = await tx.wait();
      const event = receipt?.logs[0];
      const tournamentAddress = event?.args?.tournamentAddress;

      const Tournament = await hre.ethers.getContractFactory("Tournament");
      const tournament = Tournament.attach(tournamentAddress);

      // Add some prize pool
      await baseFixture.owner.sendTransaction({
        to: tournamentAddress,
        value: hre.ethers.parseEther("1.0")
      });

      return {
        ...baseFixture,
        tournament,
      };
    }

    describe("Reward Distribution", function () {
      it("Should distribute rewards correctly", async function () {
        const { tournament, user1, user2, leagueEndTime, owner } = await loadFixture(
          deployTournamentFixture
        );

        await time.increaseTo(leagueEndTime + 1);

        const winners = [user1.address, user2.address];
        const amounts = [
          hre.ethers.parseEther("0.6"),
          hre.ethers.parseEther("0.4")
        ];

        // Tournament admin (owner) distributes rewards
        await expect(
          tournament.connect(owner).distributeRewards(winners, amounts)
        ).to.emit(tournament, "RewardDistributed");
      });

      it("Should allow winners to claim rewards", async function () {
        const { tournament, user1, user2, leagueEndTime, owner } = await loadFixture(
          deployTournamentFixture
        );

        await time.increaseTo(leagueEndTime + 1);

        const winners = [user1.address, user2.address];
        const amounts = [
          hre.ethers.parseEther("0.6"),
          hre.ethers.parseEther("0.4")
        ];

        // Tournament admin (owner) distributes rewards
        await tournament.connect(owner).distributeRewards(winners, amounts);

        // Winner claims reward
        await expect(
          tournament.connect(user1).claimReward()
        ).to.changeEtherBalance(user1, amounts[0]);
      });

      it("Should fail if non-winner tries to claim", async function () {
        const { tournament, user1, user2, leagueEndTime, owner, admin } = await loadFixture(
          deployTournamentFixture
        );

        await time.increaseTo(leagueEndTime + 1);

        const winners = [user1.address, user2.address];
        const amounts = [
          hre.ethers.parseEther("0.6"),
          hre.ethers.parseEther("0.4")
        ];

        await tournament.connect(owner).distributeRewards(winners, amounts);

        // Non-winner tries to claim
        await expect(
          tournament.connect(admin).claimReward()
        ).to.be.revertedWith("No reward to claim");
      });
    });
  });
})