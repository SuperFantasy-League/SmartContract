// SPDX-License Identifier: MIT
pragma solidity ^0.8.27;

import "./FantasyHelpers.sol";

contract UserTeamManager is FantasyHelpers {
    address admin;
    uint256 userCounter;
    uint256 teamCounter;

    // ACCESS CONTROL ROLES
    bytes32 public constant ADMIN_ROLE = DEFAULT_ADMIN_ROLE;
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");

    struct User {
        uint256 id;
        string name;
    }

    struct Team {
        uint256 teamId;
        uint256 leagueId;
        uint256 totalPoints;
        uint256[] playerIds;
        address owner;
    }

    mapping(address => User) public users;
    mapping(uint256 => Team) public teams;
    mapping(address user => mapping(uint256 leagueId => uint256[] teamIds)) public userTeams;
    mapping() public ;

    constructor {
        _grantRole(ADMIN_ROLE, msg.sender);
        admin = msg.sender;
    }

    // Registers a new user as a league participant or an admin
    function registerUser(string _name) external {
        checkZeroAddress();

        uint256 userCount = ++userCounter;

        User memory newUser = User(userCount, _name);
        users[msg.sender] = newUser;

        emit UserRegistered(msg.sender);
    }

    // Set specific roles for users, such as assigning player and admin rights
    // assignRole(address user, string role)

    // Allow users to create a fantasy team within a budget
    function createTeam(uint256 _leagueId, uint256[] calldata _playerIds) external {
        checkZeroAddress();

        uint256 teamCount = ++teamCounter;

        Team memory newTeam = Team({
            teamId: teamCount,
            leagueId: _leagueId,
            playerIds: _playerIds,
            owner: msg.sender
        });

        teams[teamCount] = newTeam;
        userTeams[msg.sender][_leagueId].push(teamCount);

        emit TeamCreated(msg.sender, teamCount);
    }

    // Enables users to update teams based on dynamic player statistics and valuations
    function updateTeam(uint256 _teamId, uint256[] calldata _playerIds) external {
        Team storage team = teams[_teamId];

        team.playerIds = _playerIds;

        emit TeamCreated(msg.sender, _teamId);
    }

    // REWORK !!!
    function getTeam(address user) external view returns (uint256[] memory playerIds, uint256 totalValue) {
        Team memory team = userTeams[user];
        return (team.playerIds, team.totalValue);
    }
}