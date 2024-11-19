


contract GamePlayScoring  {


	createTournament(string tournamentType, uint256[] participatingTeams): Creates a new tournament (e.g., weekly, monthly).
	recordPerformance(uint256 playerId, uint256 score): Records performance data for each player, which affects team scores.
	calculateTeamScore(address user) view returns (uint256): Calculates the fantasy team score based on each player's real-world performance.
	rewardWinners(uint256 tournamentId): Distributes rewards to the top teams based on their ranking.

}



contract Tournament {
	struct Reward {
		address winner;
		uint256 amount;
		bool claimed;
	}

	string public name;
	address public admin;
	uint256 public startTime;
	uint256 public endTime;
	uint256 public prizePool;
	bool public finished;

	mapping(address => Reward) public rewards;
	address[] public winners;

	uint256 private _status;
	uint256 private constant _NOT_ENTERED = 1;
	uint256 private constant _ENTERED = 2;

	event RewardDistributed(address indexed winner, uint256 amount);

	modifier onlyAdmin() {
		require(msg.sender == admin, "Only admin can call");
		_;
	}

	modifier nonReentrant() {
		require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
		_status = _ENTERED;
		_;
		_status = _NOT_ENTERED;
	}

	constructor(
		string memory _name,
		uint256 _startTime,
		uint256 _endTime,
		address _admin
	) {
		require(_startTime > block.timestamp, "Invalid start time");
		require(_endTime > _startTime, "Invalid end time");
		
		name = _name;
		startTime = _startTime;
		endTime = _endTime;
		admin = _admin;
		_status = _NOT_ENTERED;
	}

	function distributeRewards(
		address[] calldata _winners,
		uint256[] calldata amounts
	) external onlyAdmin {
		require(!finished, "Tournament already finished");
		require(block.timestamp > endTime, "Tournament not ended");
		require(_winners.length == amounts.length, "Arrays length mismatch");
		
		for (uint256 i = 0; i < _winners.length; i++) {
			rewards[_winners[i]] = Reward(_winners[i], amounts[i], false);
			winners.push(_winners[i]);
			emit RewardDistributed(_winners[i], amounts[i]);
		}
		
		finished = true;
	}

	function claimReward() external nonReentrant {
		require(finished, "Tournament not finished");
		Reward storage reward = rewards[msg.sender];
		require(reward.winner == msg.sender, "No reward to claim");
		require(!reward.claimed, "Reward already claimed");
		
		reward.claimed = true;
		payable(msg.sender).transfer(reward.amount);
	}

	receive() external payable {
		prizePool += msg.value;
	}
}



contract League {
	struct Team {
		address owner;
		uint256[] playerIds;
		uint256 points;
	}

	string public name;
	address public owner;
	uint256 public entryFee;
	uint256 public maxTeams;
	uint256 public startTime;
	uint256 public endTime;
	bool public active;

	PlayerCard public playerCardContract;

	mapping(address => Team) public teams;
	address[] public participants;

	uint256 private _status; // For reentrancy guard
	uint256 private constant _NOT_ENTERED = 1;
	uint256 private constant _ENTERED = 2;
	
	event TeamRegistered(address indexed owner, uint256[] playerIds);
	
	modifier nonReentrant() {
		require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
		_status = _ENTERED;
		_;
		_status = _NOT_ENTERED;
	}
	
	constructor(
		string memory _name,
		address _owner,
		uint256 _entryFee,
		uint256 _maxTeams,
		uint256 _startTime,
		uint256 _endTime,
		address _playerCardAddress
	) {
		name = _name;
		owner = _owner;
		entryFee = _entryFee;
		maxTeams = _maxTeams;
		startTime = _startTime;
		endTime = _endTime;
		active = true;
		playerCardContract = PlayerCard(_playerCardAddress);
		_status = _NOT_ENTERED;
	}
	
	function registerTeam(uint256[] calldata playerIds) external payable nonReentrant {
		require(active, "League is not active");
		require(block.timestamp < startTime, "League has already started");
		require(msg.value == entryFee, "Incorrect entry fee");
		require(participants.length < maxTeams, "League is full");
		
		// Validate player ownership
		for (uint256 i = 0; i < playerIds.length; i++) {
			require(
				playerCardContract.ownerOf(playerIds[i]) == msg.sender,
				"Must own all players"
			);
		}
		
		teams[msg.sender] = Team(msg.sender, playerIds, 0);
		participants.push(msg.sender);
		
		emit TeamRegistered(msg.sender, playerIds);
	}
}