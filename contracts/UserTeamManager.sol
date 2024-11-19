// SPDX-License Identifier: MIT
pragma solidity ^0.8.27;

import "./FantasyHelpers.sol";

contract UserTeamManager is FantasyHelpers {
	address admin;
	uint256 userCounter;

	// ACCESS CONTROL ROLES
	bytes32 public constant ADMIN_ROLE = DEFAULT_ADMIN_ROLE;
	bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
	bytes32 public constant USER_ROLE = keccak256("USER_ROLE");

	struct User {
		uint256 id;
		string name;
	}
	User[] public userList;

	mapping(address => id) users;

	constructor {
		_grantRole(ADMIN_ROLE, msg.sender);
		admin = msg.sender;
	}

	// Registers a new user as a league participant or an admin
	function registerUser(string _name) external {
		uint256 userCount = ++userCounter;

		User memory newUser = User(userCount, _name);

		users[userCounter] = newUser;
		userList.push(newUser);

		emit UserRegistered(msg.sender);
	}

	// Set specific roles for users, such as assigning player and admin rights
	// assignRole(address user, string role)

	// Allow users to create a fantasy team within a budget
	createTeam(address user, uint256[] playerIds, uint256 budget)

	// Enables users to update teams based on dynamic player statistics and valuations
	updateTeam(address user, uint256[] playerIds)
}