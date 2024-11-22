// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./UserPlayerManager.sol";
import "./League.sol";

/**
 * @title LeagueFactory
 * @notice Creates and manages fantasy football leagues
 */
contract LeagueFactory {
    UserPlayerManager public userPlayerManager;
    address public admin;
    uint256 private currentLeagueId;
    mapping(uint256 => address) public leagues;

    event LeagueCreated(uint256 indexed leagueId, address leagueAddress, string name, address owner);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

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
        uint256 endTime
    ) external returns (address) {
        require(bytes(name).length > 0, "Empty name");
        require(startTime > block.timestamp, "Start time must be future");
        require(endTime > startTime, "End time must be after start");
        require(maxTeams > 0, "Invalid max teams");
        
        currentLeagueId++;
        
        League newLeague = new League(
            currentLeagueId,
            name,
            msg.sender,
            entryFee,
            maxTeams,
            startTime,
            endTime,
            address(userPlayerManager)
        );
        
        address leagueAddress = address(newLeague);
        leagues[currentLeagueId] = leagueAddress;
        
        emit LeagueCreated(currentLeagueId, leagueAddress, name, msg.sender);
        return leagueAddress;
    }

    function getLeague(uint256 leagueId) external view returns (address) {
        require(leagueId > 0 && leagueId <= currentLeagueId, "Invalid league ID");
        return leagues[leagueId];
    }

    function getCurrentLeagueId() external view returns (uint256) {
        return currentLeagueId;
    }
}