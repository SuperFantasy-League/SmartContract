// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
import "./UserPlayerManager.sol";

/**
 * @title League
 * @notice Individual league contract for fantasy football
 */
contract League {
    uint256 public constant WEEK_DURATION = 7 days;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;
    address public immutable leagueFactory;

    UserPlayerManager public userPlayerManager;

    struct Team {
        address owner;
        uint256[] playerIds;
        uint256 points;
        bool isRegistered;
    }

    uint256 public leagueId;
    string public name;
    address public owner;
    uint256 public entryFee;
    uint256 public maxTeams;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public currentWeek;
    uint256 public totalPrizePool;
    bool public active;

    address[] public participants;
    // mapping(address => Team) public teams;
    mapping(address => mapping(uint256 => Team)) public teams;
    mapping(uint256 => address) public weeklyWinners;
    mapping(uint256 => bool) public weeklyRewardsClaimed;
    mapping(uint256 => uint256) public weeklyPrizePools;

    event LeagueJoined(address indexed user, uint256 leagueId);
    event TeamRegistered(address indexed owner, uint256[] playerIds);
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
        uint256 _maxTeams,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _currentLeagueWeek,
        address _userPlayerManagerAddress
    ) {
        leagueId = _leagueId;
        name = _name;
        owner = _owner;
        entryFee = _entryFee;
        maxTeams = _maxTeams;
        startTime = _startTime;
        endTime = _endTime;
        currentWeek = _currentLeagueWeek;
        userPlayerManager = UserPlayerManager(_userPlayerManagerAddress);
        leagueFactory = msg.sender;
        active = true;
        _status = _NOT_ENTERED;
    }

    function joinLeague() external payable nonReentrant {
        require(msg.value == entryFee, "Incorrect entry fee");
        require(participants.length < maxTeams, "League is full");
        require(
            !teams[msg.sender][currentWeek].isRegistered,
            "Team already registered"
        );
        require(active, "League is not active");

        userPlayerManager.addUserLeague(msg.sender, leagueId);
        totalPrizePool += msg.value;

        uint256 weeksInLeague = (endTime - startTime) / WEEK_DURATION;
        uint256 weeklyPrize = msg.value / weeksInLeague;
        for (uint256 week = 0; week < weeksInLeague; week++) {
            weeklyPrizePools[week] += weeklyPrize;
        }
        emit LeagueJoined(msg.sender, leagueId);
    }

    function registerCreatorTeam(
        address creator,
        uint256[] calldata playerIds
    ) external {
        require(msg.sender == leagueFactory, "Only factory");

        teams[creator][currentWeek] = Team(creator, playerIds, 0, true);
        participants.push(creator);

        emit TeamRegistered(creator, playerIds);
    }

    function registerTeam(uint256[] calldata playerIds) external {
        require(active, "League is not active");
        require(block.timestamp < startTime, "League has started");
        require(
            !teams[msg.sender][currentWeek].isRegistered,
            "Already registered this week"
        );

        // Validate team composition
        require(
            userPlayerManager.validateTeamPlayers(playerIds),
            "Invalid team composition"
        );

        // Create new team for this week
        teams[msg.sender][currentWeek] = Team(msg.sender, playerIds, 0, true);

        emit TeamRegistered(msg.sender, playerIds);
    }

    function calculateTeamPoints(
        address teamOwner,
        uint256 weekNumber
    ) public view returns (uint256) {
        require(
            teams[teamOwner][weekNumber].isRegistered,
            "Team not registered"
        );

        uint256 totalPoints = 0;
        uint256[] memory playerIds = teams[teamOwner][weekNumber].playerIds;

        for (uint256 i = 0; i < playerIds.length; i++) {
            totalPoints += userPlayerManager.getPlayerWeeklyPoints(
                playerIds[i],
                weekNumber
            );
        }

        return totalPoints;
    }

    function updateTeamPoints(uint256 weekNumber) external onlyOwner {
        require(
            block.timestamp >= startTime + (weekNumber * WEEK_DURATION),
            "Week not finished"
        );

        for (uint256 i = 0; i < participants.length; i++) {
            address participant = participants[i];
            uint256 points = calculateTeamPoints(participant, weekNumber);
            teams[participant][weekNumber].points = points;
            emit PointsUpdated(participant, points);
        }
    }

    function declareWeeklyWinner(uint256 weekNumber) external onlyOwner {
        require(
            block.timestamp >= startTime + (weekNumber * WEEK_DURATION),
            "Week not finished"
        );
        require(!weeklyRewardsClaimed[weekNumber], "Already declared");

        address winner = address(0);
        uint256 highestPoints = 0;

        for (uint256 i = 0; i < participants.length; i++) {
            address participant = participants[i];
            if (teams[participant][weekNumber].points > highestPoints) {
                highestPoints = teams[participant][weekNumber].points;
                winner = participant;
            }
        }

        require(winner != address(0), "No winner found");

        weeklyWinners[weekNumber] = winner;
        weeklyRewardsClaimed[weekNumber] = true;

        emit WeeklyWinnerDeclared(
            weekNumber,
            winner,
            weeklyPrizePools[weekNumber]
        );
    }

    function claimWeeklyReward(uint256 weekNumber) external nonReentrant {
        require(weeklyRewardsClaimed[weekNumber], "Winner not declared");
        require(weeklyWinners[weekNumber] == msg.sender, "Not the winner");
        require(weeklyPrizePools[weekNumber] > 0, "No prize to claim");

        uint256 prize = weeklyPrizePools[weekNumber];
        weeklyPrizePools[weekNumber] = 0;

        payable(msg.sender).transfer(prize);
        emit RewardClaimed(weekNumber, msg.sender, prize);
    }

    // function getCurrentWeek() public view returns (uint256) {
    //     if (block.timestamp < startTime) return 0;
    //     return (block.timestamp - startTime) / WEEK_DURATION;
    // }

    function advanceWeek() external {
        require(msg.sender == owner, "Only admin can advance week");
        currentWeek++;
        emit WeekAdvanced(currentWeek);
    }
}
