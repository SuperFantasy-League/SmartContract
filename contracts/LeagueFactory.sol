// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./UserPlayerManager.sol";
import "./League.sol";

contract LeagueFactory {
    UserPlayerManager public userPlayerManager;
    address public admin;
    uint256 private currentLeagueCounter;
    uint256 public currentLeagueWeek = 1;
    mapping(uint256 => address) public leagues;

    event LeagueCreated(
        uint256 indexed leagueId,
        address leagueAddress,
        string name,
        address owner
    );

    constructor(address _userPlayerManager) {
        require(_userPlayerManager != address(0), "Invalid UserPlayerManager");
        userPlayerManager = UserPlayerManager(_userPlayerManager);
        admin = msg.sender;
    }

    function createLeague(
        string memory name,
        uint256 entryFee,
        uint256 maxTeams,
        uint256 startTime,
        uint256 endTime,
        uint256[] calldata playerIds
    ) external payable returns (address) {
        require(bytes(name).length > 0, "Empty name");
        require(startTime > block.timestamp, "Start time must be future");
        require(endTime > startTime, "End time must be after start");
        require(maxTeams > 0, "Invalid max teams");
        require(msg.value == entryFee, "Incorrect entry fee");
        require(
            userPlayerManager.validateTeamPlayers(playerIds),
            "Invalid team composition"
        );

        uint256 currentLeagueId = ++currentLeagueCounter;

        League newLeague = new League(
            currentLeagueId,
            name,
            msg.sender,
            entryFee,
            maxTeams,
            startTime,
            endTime,
            currentLeagueWeek,
            address(userPlayerManager)
        );

        address leagueAddress = address(newLeague);
        leagues[currentLeagueId] = leagueAddress;

        // Register creator's team
        League(leagueAddress).registerCreatorTeam(msg.sender, playerIds);
        userPlayerManager.addUserLeague(msg.sender, currentLeagueId);

        emit LeagueCreated(currentLeagueId, leagueAddress, name, msg.sender);
        return leagueAddress;
    }

    function getLeague(uint256 leagueId) external view returns (address) {
        require(
            leagueId > 0 && leagueId <= currentLeagueCounter,
            "Invalid league ID"
        );
        return leagues[leagueId];
    }
}
