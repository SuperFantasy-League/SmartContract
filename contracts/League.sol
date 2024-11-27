// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
import "./UserPlayerManager.sol";

/**
 * @title League
 * @notice Individual league contract for fantasy football
 */
contract League {
    uint256 public constant CONTEST_DURATION = 7 days;
    uint256 public immutable SEASON_DURATION;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    UserPlayerManager public userPlayerManager;
    address public immutable leagueFactory;

    uint256 public leagueId;
    string public name;
    address public owner;
    uint256 public entryFee;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public currentWeek;
    uint256 public totalPrizePool;
    bool public active;

    address[] public leagueParticipants;
    mapping(address => bool) public isParticipant;
    mapping(address => uint256[]) public leagueTeams;
    mapping(address => mapping(uint256 leagueId => bool)) public validTeams;
    mapping(uint256 => address) public weeklyWinners;
    mapping(uint256 => bool) public weeklyRewardsDeclared;
    mapping(uint256 => bool) public weeklyRewardsClaimed;
    mapping(uint256 => uint256) public weeklyPrizePools;

    event LeagueJoined(address indexed user, uint256 leagueId);
    event TeamAdded(
        address indexed user,
        uint256 indexed leagueId,
        uint256 indexed teamId
    );
    event PointsUpdated(address indexed teamOwner, uint256 newPoints);
    event WeeklyWinnerDeclared(
        uint256 indexed weekNumber,
        address winner,
        uint256 prize
    );
    event RewardClaimed(
        uint256 indexed weekNumber,
        address winner,
        uint256 amount
    );
    event WeekAdvanced(uint256 currentWeek);

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call");
        _;
    }

    constructor(
        uint256 _leagueId,
        string memory _name,
        address _owner,
        uint256 _entryFee,
        uint256 _startTime,
        uint256 _endTime,
        // uint256 _currentLeagueWeek,
        address _userPlayerManagerAddress
    ) {
        leagueId = _leagueId;
        name = _name;
        owner = _owner;
        entryFee = _entryFee;
        startTime = _startTime;
        endTime = _endTime;
        // currentWeek = _currentLeagueWeek;
        userPlayerManager = UserPlayerManager(_userPlayerManagerAddress);
        leagueParticipants.push(owner);
        isParticipant[owner] = true;
        leagueFactory = msg.sender;
        active = true;
        _status = _NOT_ENTERED;
    }

    function joinLeague(uint256 _leagueId) external payable nonReentrant {
        require(msg.value == entryFee, "Incorrect entry fee");
        require(!isParticipant[msg.sender], "Already joined league");
        require(msg.sender != owner, "Already in league");
        require(block.timestamp < startTime, "League has started");
        require(active, "League is not active");

        userPlayerManager.addUserToLeague(msg.sender, _leagueId);
        leagueParticipants.push(msg.sender);
        isParticipant[msg.sender] = true;

        userPlayerManager.addTransaction(
            UserPlayerManager.TransactionType.STAKE,
            msg.value,
            msg.sender,
            address(this),
            _leagueId
        );

        totalPrizePool += msg.value;
        uint256 weeksInLeague = (endTime - startTime) / CONTEST_DURATION;
        uint256 weeklyPrize = msg.value / weeksInLeague;
        for (uint256 week = 0; week < weeksInLeague; week++) {
            weeklyPrizePools[week] += weeklyPrize;
        }

        emit LeagueJoined(msg.sender, leagueId);
    }

    function calculateTeamPoints(
        address teamOwner,
        uint256 _teamId,
        uint256 weekNumber
    ) public view returns (uint256) {
        require(validTeams[teamOwner][leagueId], "Team not registered");

        UserPlayerManager.Team memory team = userPlayerManager.getTeam(
            teamOwner,
            _teamId
        );
        uint256[] memory playerIds = team.playerIds;
        uint256 totalPoints = 0;

        for (uint256 i = 0; i < playerIds.length; i++) {
            totalPoints += userPlayerManager.getPlayerWeeklyPoints(
                playerIds[i],
                weekNumber
            );
        }

        return totalPoints;
    }

    function updateTeamPoints(
        uint256 _teamId,
        uint256 weekNumber
    ) external onlyOwner {
        require(
            block.timestamp >= startTime + (weekNumber * CONTEST_DURATION),
            "Week not finished"
        );

        for (uint256 i = 0; i < leagueParticipants.length; i++) {
            address participant = leagueParticipants[i];
            uint256 points = calculateTeamPoints(
                participant,
                _teamId,
                weekNumber
            );

            UserPlayerManager.Team memory team = userPlayerManager.getTeam(
                participant,
                _teamId
            );
            team.points = points;

            // userPlayerManager.updateWeeklyPoints(
            //     participant,
            //     weekNumber,
            //     points
            // );

            emit PointsUpdated(participant, points);
        }
    }

    function declareWeeklyWinner(
        uint256 _teamId,
        uint256 weekNumber
    ) external onlyOwner {
        require(
            block.timestamp >= startTime + (weekNumber * CONTEST_DURATION),
            "Week not finished"
        );
        require(!weeklyRewardsDeclared[weekNumber], "Already declared");

        address winner = address(0);
        uint256 highestPoints = 0;

        for (uint256 i = 0; i < leagueParticipants.length; i++) {
            address participant = leagueParticipants[i];
            for (uint256 j = 0; j < leagueTeams[participant].length; j++) {
                UserPlayerManager.Team memory team = userPlayerManager.getTeam(
                    participant,
                    _teamId
                );

                if (team.points > highestPoints) {
                    highestPoints = team.points;
                    winner = participant;
                }
            }
        }

        require(winner != address(0), "No winner found");

        weeklyWinners[weekNumber] = winner;
        weeklyRewardsDeclared[weekNumber] = true;

        emit WeeklyWinnerDeclared(
            weekNumber,
            winner,
            weeklyPrizePools[weekNumber]
        );
    }

    function claimWeeklyReward(uint256 weekNumber) external nonReentrant {
        require(weeklyRewardsDeclared[weekNumber], "Winner not declared");
        require(!weeklyRewardsClaimed[weekNumber], "Winner already claimed");
        require(weeklyWinners[weekNumber] == msg.sender, "Not the winner");
        require(weeklyPrizePools[weekNumber] > 0, "No prize to claim");

        uint256 prize = weeklyPrizePools[weekNumber];
        weeklyPrizePools[weekNumber] = 0;
        weeklyRewardsClaimed[weekNumber] = true;

        userPlayerManager.updateUserBalances(msg.sender, prize);
        emit RewardClaimed(weekNumber, msg.sender, prize);
    }

    // function getCurrentWeek() public view returns (uint256) {
    //     if (block.timestamp < startTime) return 0;
    //     return (block.timestamp - startTime) / CONTEST_DURATION;
    // }

    function advanceWeek() external {
        require(msg.sender == owner, "Only admin can advance week");
        currentWeek++;
        emit WeekAdvanced(currentWeek);
    }

    function addTeam(uint256 _teamId) external {
        require(isParticipant[msg.sender], "Must join league");
        require(!validTeams[msg.sender][leagueId], "Already in league");

        // Validate team
        UserPlayerManager.Team memory team = userPlayerManager.getTeam(
            msg.sender,
            _teamId
        );
        require(team.exists, "Team does not exist");
        require(!team.isRegistered, "Team already registered");
        require(team.owner == msg.sender, "Not team owner");

        // Update team in UserPlayerManager
        userPlayerManager.registerTeamInLeague(_teamId, msg.sender, leagueId);

        // Track in League contract
        validTeams[msg.sender][leagueId] = true;
        leagueTeams[msg.sender].push(_teamId);

        emit TeamAdded(msg.sender, leagueId, _teamId);
    }

    function getParticipants() external view returns (address[] memory) {
        return leagueParticipants;
    }
}
