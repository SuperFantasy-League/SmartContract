// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

contract UserPlayerManager {
    address public admin;
    uint256 public userCounter;
    uint256 public teamCounter;
    uint256 public playerCounter;
    uint256 public transactionCounter;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

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

    struct Team {
        uint256 id;
        uint256 leagueId;
        uint256 points;
        address owner;
        bool exists;
        bool isRegistered;
        uint256[] playerIds;
    }

    struct Transaction {
        bytes32 txHash;
        uint256 id;
        TransactionType txType;
        uint256 value;
        uint256 timestamp;
        address sender;
        address receiver;
        uint256 leagueId;
    }

    enum TransactionType {
        NULL,
        DEPOSIT,
        WITHDRAW,
        STAKE
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
    mapping(address => uint256[]) public userTeams;
    mapping(address => Transaction[]) public userTransactions;
    mapping(address => mapping(uint256 teamId => Team)) public allTeams;

    mapping(uint256 => Player) public players;
    mapping(string => bool) public playerNameExists;
    mapping(uint256 => mapping(uint256 => uint256)) public weeklyPlayerPoints;

    event UserRegistered(address indexed user, string name);
    event TeamCreated(
        address indexed owner,
        uint256 teamId,
        uint256[] playerIds
    );
    event PlayerCreated(
        uint256 indexed playerId,
        string name,
        string club,
        uint256 position,
        uint256 price
    );
    event PlayerPointsUpdated(
        address indexed player,
        uint256 indexed leagueId,
        uint256 weekNumber,
        uint256 points
    );
    event TransactionCreated(
        bytes32 txHash,
        uint256 indexed id,
        uint256 indexed txType,
        uint256 value,
        address indexed sender,
        address receiver,
        uint256 leagueId
    );
    event DepositSuccessful(address indexed sender, uint amount);
    event WithdrawSuccessful(address indexed receiver, uint amount);
    event TeamRegisteredInLeague(
        uint256 indexed teamId,
        address indexed owner,
        uint256 indexed leagueId
    );

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: Reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // function registerUser(string calldata _name) external {
    //     require(msg.sender != address(0), "Invalid address");
    //     require(!users[msg.sender].isRegistered, "Already registered");
    //     require(bytes(_name).length > 0, "Empty name");

    //     uint256 userId = ++userCounter;
    //     users[msg.sender] = User(userId, _name, true);

    //     emit UserRegistered(msg.sender, _name);
    // }

    function createTeam(uint256[] calldata _playerIds) external {
        require(_playerIds.length == TEAM_SIZE, "Invalid team size");
        // require(validateTeamPlayers(_playerIds), "Invalid team composition");

        uint256 currentTeamId = ++teamCounter;

        allTeams[msg.sender][currentTeamId] = Team({
            id: currentTeamId,
            leagueId: 0,
            points: 0,
            owner: msg.sender,
            exists: true,
            isRegistered: false,
            playerIds: _playerIds
        });

        userTeams[msg.sender].push(currentTeamId);

        emit TeamCreated(msg.sender, currentTeamId, _playerIds);
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

    function getTeam(
        address _owner,
        uint256 _teamId
    ) external view returns (Team memory) {
        Team memory team = allTeams[_owner][_teamId];
        require(team.exists, "Team not found");
        return team;
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

    // function updateWeeklyPoints(
    //     address _player,
    //     uint256 _leagueId,
    //     uint256 _weekNumber,
    //     uint256 _points
    // ) external {
    //     require(msg.sender == admin, "Only admin can update points");

    //     // Check if player is in this league
    //     bool isInLeague = false;
    //     uint256[] memory playerLeagues = userLeagues[_player];
    //     for (uint256 i = 0; i < playerLeagues.length; i++) {
    //         if (playerLeagues[i] == _leagueId) {
    //             isInLeague = true;
    //             break;
    //         }
    //     }
    //     require(isInLeague, "Player not in this league");

    //     // Get and update team points
    //     Team storage team = userTeams[_player][_leagueId];
    //     require(team.exists, "Team not found");
    //     team.points = _points;

    //     emit PlayerPointsUpdated(_player, _leagueId, _weekNumber, _points);
    // }

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
    ) external view returns (Player memory player) {
        require(_playerId <= playerCounter, "Invalid player ID");
        player = players[_playerId];
    }

    function getPlayerWeeklyPoints(
        uint256 _playerId,
        uint256 _weekNumber
    ) external view returns (uint256) {
        require(_playerId <= playerCounter, "Invalid player ID");
        return weeklyPlayerPoints[_playerId][_weekNumber];
    }

    function addUserToLeague(address _user, uint256 _leagueId) external {
        userLeagues[_user].push(_leagueId);
    }

    function addTeamToUser(address _user, uint256 _teamId) external {
        userTeams[_user].push(_teamId);
    }

    function deposit() external payable nonReentrant {
        require(msg.sender != address(0), "Zero address detected!");
        require(msg.value > 0, "Cannot deposit zero!");

        userBalances[msg.sender] += msg.value;

        addTransaction(
            TransactionType.DEPOSIT,
            msg.value,
            msg.sender,
            address(this),
            0 // no league involved
        );

        emit DepositSuccessful(msg.sender, msg.value);
    }

    function withdraw(uint256 _amount) external nonReentrant {
        require(msg.sender != address(0), "Zero address detected!");
        require(_amount > 0, "Cannot withdraw zero!");
        require(userBalances[msg.sender] >= _amount, "Insufficient funds!");

        userBalances[msg.sender] -= _amount;

        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "Ether transfer failed!");

        addTransaction(
            TransactionType.WITHDRAW,
            _amount,
            msg.sender,
            msg.sender,
            0 // no league involved
        );

        emit WithdrawSuccessful(msg.sender, _amount);
    }

    function updateUserBalances(address _user, uint256 _amount) external {
        userBalances[_user] += _amount;
    }

    function getBalance(address _user) external view returns (uint256) {
        return userBalances[_user];
    }

    function addTransaction(
        TransactionType _type,
        uint256 _value,
        address _sender,
        address _receiver,
        uint256 _leagueId
    ) public returns (uint256) {
        uint256 txId = ++transactionCounter;

        bytes32 txHash = keccak256(
            abi.encodePacked(
                txId,
                uint256(_type),
                _value,
                block.timestamp,
                _sender,
                _receiver,
                _leagueId
            )
        );

        Transaction memory newTx = Transaction({
            txHash: txHash,
            id: txId,
            txType: _type,
            value: _value,
            timestamp: block.timestamp,
            sender: _sender,
            receiver: _receiver,
            leagueId: _leagueId
        });

        userTransactions[_sender].push(newTx);

        emit TransactionCreated(
            txHash,
            txId,
            uint256(_type),
            _value,
            _sender,
            _receiver,
            _leagueId
        );

        return txId;
    }

    function getUserTransactions(
        address _user
    ) external view returns (Transaction[] memory) {
        return userTransactions[_user];
    }

    function registerTeamInLeague(
        uint256 _teamId,
        address _owner,
        uint256 _leagueId
    ) external {
        require(msg.sender != address(0), "Zero Address detected");

        Team storage team = allTeams[_owner][_teamId];
        require(team.exists, "Team does not exist");
        require(!team.isRegistered, "Team already registered");
        require(team.owner == _owner, "Not team owner");

        team.isRegistered = true;
        team.leagueId = _leagueId;

        emit TeamRegisteredInLeague(_teamId, _owner, _leagueId);
    }
}
