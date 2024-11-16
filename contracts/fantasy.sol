// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title LeagueFactory
 * @notice Factory contract for creating new leagues
 */
contract LeagueFactory is AccessControl {
    address public immutable playerCardAddress;
    address[] public leagues;
    
    event LeagueCreated(address indexed leagueAddress, string name, address indexed owner);
    
    constructor(address _playerCardAddress) {
        playerCardAddress = _playerCardAddress;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    function createLeague(
        string memory name,
        uint256 entryFee,
        uint256 maxTeams,
        uint256 startTime,
        uint256 endTime
    ) external returns (address) {
        League newLeague = new League(
            name,
            msg.sender,
            entryFee,
            maxTeams,
            startTime,
            endTime,
            playerCardAddress
        );
        
        address leagueAddress = address(newLeague);
        leagues.push(leagueAddress);
        
        emit LeagueCreated(leagueAddress, name, msg.sender);
        return leagueAddress;
    }
    
    function getLeagues() external view returns (address[] memory) {
        return leagues;
    }
}

/**
 * @title League 
 * @notice Individual league contract created by factory
 */
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

/**
 * @title TournamentFactory
 * @notice Factory contract for creating new tournaments
 */
contract TournamentFactory is AccessControl {
    address[] public tournaments;
    
    event TournamentCreated(address indexed tournamentAddress, string name, address indexed admin);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    function createTournament(
        string memory name,
        uint256 startTime,
        uint256 endTime
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (address) {
        Tournament newTournament = new Tournament(
            name,
            startTime,
            endTime,
            msg.sender
        );
        
        address tournamentAddress = address(newTournament);
        tournaments.push(tournamentAddress);
        
        emit TournamentCreated(tournamentAddress, name, msg.sender);
        return tournamentAddress;
    }
    
    function getTournaments() external view returns (address[] memory) {
        return tournaments;
    }
}

/**
 * @title Tournament
 * @notice Individual tournament contract created by factory
 */
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

/**
 * @title PlayerCard
 * @notice NFT contract for player cards
 */
contract PlayerCard is ERC721, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 private _currentTokenId;
    
    struct Player {
        string name;
        uint256 position; // 1: GK, 2: DEF, 3: MID, 4: FWD
        uint256 team;
        uint256 value;
        uint256 points;
    }
    
    mapping(uint256 => Player) public players;
    
    constructor() ERC721("SuperFantasy Player", "SFP") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }
    
    function mintPlayer(
        address to,
        string memory name,
        uint256 position,
        uint256 team,
        uint256 value
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        _currentTokenId += 1;
        uint256 newTokenId = _currentTokenId;
        
        players[newTokenId] = Player(name, position, team, value, 0);
        _mint(to, newTokenId);
        
        return newTokenId;
    }
    
    function updatePlayerPoints(uint256 tokenId, uint256 newPoints) 
        external 
        onlyRole(MINTER_ROLE) 
    {
        require(_ownerOf(tokenId) != address(0), "Player does not exist");
        players[tokenId].points = newPoints;
    }

    function updatePlayerValue(uint256 tokenId, uint256 newValue) 
        external 
        onlyRole(MINTER_ROLE) 
    {
        require(_ownerOf(tokenId) != address(0), "Player does not exist");
        players[tokenId].value = newValue;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}