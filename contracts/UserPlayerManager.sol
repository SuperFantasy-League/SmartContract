// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

contract UserPlayerManager {
    address public admin;
    uint256 public userCounter;
    uint256 public playerCounter;

    struct User {
        uint256 id;
        string name;
        bool isRegistered;
        // uint256[] seasonPoints;
    }

    struct Player {
        uint256 playerId;
        string name;
        string club;
        uint256 position; // 1: GK, 2: DEF, 3: MID, 4: FWD
        uint256 price;
        uint256 points;
        bool isActive;
    }

    // Team composition requirements
    uint256 public constant REQUIRED_GOALKEEPERS = 2;
    uint256 public constant REQUIRED_DEFENDERS = 5;
    uint256 public constant REQUIRED_MIDFIELDERS = 5;
    uint256 public constant REQUIRED_FORWARDS = 3;
    uint256 public constant TEAM_SIZE = 15;

    mapping(address => User) public users;
    mapping(address => uint256) public userBalances;
    mapping(address => uint256[]) public userLeagues;
    mapping(uint256 => Player) public players;
    mapping(string => bool) public playerNameExists;
    mapping(uint256 => mapping(uint256 => uint256)) public weeklyPlayerPoints;

    event UserRegistered(address indexed user, string name);
    event PlayerCreated(
        uint256 indexed playerId,
        string name,
        string club,
        uint256 position,
        uint256 price
    );
    event PlayerPointsUpdated(
        uint256 indexed playerId,
        uint256 weekNumber,
        uint256 points
    );

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    function registerUser(string calldata _name) external {
        require(msg.sender != address(0), "Invalid address");
        require(!users[msg.sender].isRegistered, "Already registered");
        require(bytes(_name).length > 0, "Empty name");

        uint256 userId = ++userCounter;
        users[msg.sender] = User(userId, _name, true);

        emit UserRegistered(msg.sender, _name);
    }

    function createPlayer(
        string calldata _name,
        string calldata _club,
        uint256 _position,
        uint256 _price
    ) external onlyAdmin {
        require(bytes(_name).length > 0, "Empty name");
        require(bytes(_club).length > 0, "Empty club");
        require(_price > 0, "Invalid price");
        require(!playerNameExists[_name], "Player exists");

        uint256 playerId = ++playerCounter;
        players[playerId] = Player(
            playerId,
            _name,
            _club,
            _position,
            _price,
            0,
            true
        );
        playerNameExists[_name] = true;

        emit PlayerCreated(playerId, _name, _club, _position, _price);
    }

    function updatePlayer(
        uint256 _playerId,
        string memory _club,
        uint256 _position,
        uint256 _price,
        bool _isActive
    ) external onlyAdmin {
        require(_playerId <= playerCounter, "Invalid player ID");

        Player storage pl = players[_playerId];
        pl.club = _club;
        pl.position = _position;
        pl.price = _price;
        pl.isActive = _isActive;
    }

    function updateWeeklyPoints(
        uint256 _playerId,
        uint256 _weekNumber,
        uint256 _points
    ) external onlyAdmin {
        require(_playerId <= playerCounter, "Invalid player ID");

        weeklyPlayerPoints[_playerId][_weekNumber] = _points;
        players[_playerId].points += _points;

        emit PlayerPointsUpdated(_playerId, _weekNumber, _points);
    }

    function validateTeamPlayers(
        uint256[] calldata playerIds
    ) public view returns (bool) {
        require(playerIds.length == TEAM_SIZE, "Invalid team size");

        uint256 gkCount;
        uint256 defCount;
        uint256 midCount;
        uint256 fwdCount;

        for (uint256 i = 0; i < playerIds.length; i++) {
            require(playerIds[i] <= playerCounter, "Invalid player ID");
            Player memory player = players[playerIds[i]];
            require(player.isActive, "Inactive player");

            if (player.position == 1) gkCount++;
            else if (player.position == 2) defCount++;
            else if (player.position == 3) midCount++;
            else if (player.position == 4) fwdCount++;
        }

        return (gkCount == REQUIRED_GOALKEEPERS &&
            defCount == REQUIRED_DEFENDERS &&
            midCount == REQUIRED_MIDFIELDERS &&
            fwdCount == REQUIRED_FORWARDS);
    }

    function getPlayer(
        uint256 _playerId
    )
        external
        view
        returns (
            string memory name,
            string memory club,
            uint256 position,
            uint256 price,
            uint256 points,
            bool isActive
        )
    {
        require(_playerId <= playerCounter, "Invalid player ID");
        Player memory player = players[_playerId];
        return (
            player.name,
            player.club,
            player.position,
            player.price,
            player.points,
            player.isActive
        );
    }

    function getPlayerWeeklyPoints(
        uint256 _playerId,
        uint256 _weekNumber
    ) external view returns (uint256) {
        require(_playerId <= playerCounter, "Invalid player ID");
        return weeklyPlayerPoints[_playerId][_weekNumber];
    }

    function calculateTeamValue(
        uint256[] calldata playerIds
    ) external view returns (uint256) {
        uint256 totalValue = 0;
        for (uint256 i = 0; i < playerIds.length; i++) {
            require(playerIds[i] <= playerCounter, "Invalid player ID");
            totalValue += players[playerIds[i]].price;
        }
        return totalValue;
    }

    function addUserLeague(address _user, uint256 _leagueId) external {
        userLeagues[_user].push(_leagueId);
    }

    function getBalance() external view returns (uint256) {
        return userBalances[msg.sender];
    }
}
