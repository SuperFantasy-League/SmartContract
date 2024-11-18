# AceFantasy Platform Smart Contracts

AceFantasy is a decentralized fantasy football platform where users can create leagues, manage teams, trade player cards as NFTs, and participate in tournaments.

## Table of Contents

- Contract Architecture
- Prerequisites
- Setup & Deployment
- Contract Interactions
- System Features
- User Flows
- Technical Notes

### Contract Architecture

The platform consists of four main smart contracts:
PlayerCard (NFT)
    │
    ├── LeagueFactory
    │       └── League (Individual Instances)
    │
    └── TournamentFactory
            └── Tournament (Individual Instances)

Core Contracts

PlayerCard.sol

ERC721 NFT implementation
Represents football players as NFTs
Manages player stats and values

LeagueFactory.sol

Creates new league instances
Tracks all created leagues
Manages league deployment

League.sol

Individual league instance
Handles team registration
Manages league participants

TournamentFactory.sol

Creates new tournament instances
Tracks all tournaments
Manages tournament deployment

Tournament.sol

Individual tournament instance
Handles reward distribution
Manages winners and prizes

Prerequisites

Solidity ^0.8.20
OpenZeppelin Contracts

ERC721
AccessControl

Setup & Deployment

Initial Deployment

solidityCopy// Deploy player card contract first
PlayerCard playerCard = new PlayerCard();

// Deploy factories with required addresses
LeagueFactory leagueFactory = new LeagueFactory(address(playerCard));
TournamentFactory tournamentFactory = new TournamentFactory();

Role Assignment

solidityCopy// Set up minter role for player cards
playerCard.grantRole(MINTER_ROLE, adminAddress);

// Tournament factory admin role
tournamentFactory.grantRole(DEFAULT_ADMIN_ROLE, adminAddress);
Contract Interactions

1. Player Card Management
solidityCopy// Mint new player card
playerCard.mintPlayer(
    ownerAddress,
    "Player Name",
    position,    // 1:GK, 2:DEF, 3:MID, 4:FWD
    teamId,
    initialValue
);

// Update player stats
playerCard.updatePlayerPoints(tokenId, newPoints);
playerCard.updatePlayerValue(tokenId, newValue);
2. League Operations
solidityCopy// Create new league
address leagueAddress = leagueFactory.createLeague(
    "League Name",
    entryFee,
    maxTeams,
    startTime,
    endTime
);

// Register team in league
League league = League(leagueAddress);
league.registerTeam{value: entryFee}(playerIds);
3. Tournament Operations
solidityCopy// Create new tournament
address tournamentAddress = tournamentFactory.createTournament(
    "Tournament Name",
    startTime,
    endTime
);

// Distribute rewards
Tournament tournament = Tournament(tournamentAddress);
tournament.distributeRewards(winners, amounts);

// Claim rewards
tournament.claimReward();
System Features
Player Cards (NFTs)

Unique digital representation of football players
Dynamic stats and values
Transferable ownership

Leagues

Customizable parameters (entry fee, team size)
Team registration system
Player ownership verification
Points tracking

Tournaments

Flexible reward distribution
Secure prize pool management
Claim system for winners

User Flows
Creating and Managing a League

League Creation

solidityCopy// Admin creates league
address leagueAddress = leagueFactory.createLeague(params);

Team Registration

solidityCopy// Users register teams
League(leagueAddress).registerTeam{value: fee}(playerIds);
Tournament Participation

Tournament Creation

solidityCopy// Admin creates tournament
address tournamentAddress = tournamentFactory.createTournament(params);

Reward Distribution

solidityCopy// Admin distributes rewards after tournament
Tournament(tournamentAddress).distributeRewards(winners, amounts);

Claiming Rewards

solidityCopy// Winners claim their rewards
Tournament(tournamentAddress).claimReward();
Technical Notes
Security Features

Access Control

Role-based permissions using OpenZeppelin's AccessControl
Specific roles for minting and tournament management

Reentrancy Protection

Custom reentrancy guard for financial transactions
Status checks before sensitive operations

Value Verification

Entry fee validation
Player ownership verification
Tournament timing checks

Gas Optimization

Factory Pattern

Reduces deployment costs
Optimizes contract size
Better state management

Event Logging

Key actions emit events
Efficient frontend integration
Transaction tracking

Upgradability Considerations

Each league and tournament is an independent contract
New versions can be deployed without affecting existing instances
Factory contracts can be upgraded to create new versions

Best Practices

League Creation

Set reasonable max team limits
Configure appropriate time windows
Consider entry fee economics

Tournament Management

Plan reward distribution carefully
Ensure sufficient prize pool before distribution
Verify winner addresses

Player Card Updates

Regular stat updates
Value adjustments based on performance
Maintain accurate player data

Development and Testing

Local Development
bashCopy# Install dependencies
npm install @openzeppelin/contracts

# Compile contracts

npx hardhat compile

# Run tests

npx hardhat test

Deployment Checklist

Deploy PlayerCard contract
Deploy factories with correct addresses
Set up roles and permissions
Verify contracts on explorer
Test basic functionality

Maintenance

Regular Tasks

Update player stats
Monitor league activity
Process tournament rewards

Emergency Procedures

Pause functionality if needed
Handle prize pool securely
Address user concerns
