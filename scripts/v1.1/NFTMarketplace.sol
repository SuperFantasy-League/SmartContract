// SPDX-License Identifier: MIT
pragma solidity ^0.8.27;

import "./FantasyHelpers.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PlayerCardNFTMarketplace is ERC721Enumerable, AccessControl {
    // Roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant SCORER_ROLE = keccak256("SCORER_ROLE");

    // Struct for Player Card Metadata
    struct PlayerCard {
        uint256 playerId;
        string playerName;
        uint256 weekNumber;
        uint256 performanceScore;
        string ipfsHash;
        uint256 mintedAt;
        uint256 mintPrice;
    }

    // Mappings and Storage
    mapping(uint256 => PlayerCard) public playerCards;
    mapping(uint256 => bool) public weeklyCardsMinted;
    mapping(address => uint256[]) public userOwnedCards;

    uint256 private _tokenIdCounter;

    // Events
    event PlayerCardMinted(
        uint256 indexed tokenId,
        uint256 indexed playerId,
        address indexed minter,
        string playerName,
        uint256 weekNumber,
        uint256 performanceScore
    );
    event PlayerCardListed(
        uint256 indexed tokenId,
        address seller,
        uint256 price
    );
    event PlayerCardSold(
        uint256 indexed tokenId,
        address seller,
        address buyer,
        uint256 price
    );

    // Marketplace Parameters
    uint256 public constant MAX_CARDS_PER_WEEK = 10;
    uint256 public mintingPrice;
    uint256 public platformFeePercentage;
    address public platformFeeReceiver;

    // External Data Source (Chainlink or custom oracle)
    address public dataProvider;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _mintingPrice,
        uint256 _platformFeePercentage,
        address _platformFeeReceiver
    ) ERC721(_name, _symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);

        mintingPrice = _mintingPrice;
        platformFeePercentage = _platformFeePercentage;
        platformFeeReceiver = _platformFeeReceiver;
    }

    /**
     * Mint weekly top-performing player cards
     * @param _playerIds Array of player IDs to mint
     * @param _playerNames Array of player names
     * @param _weekNumber Current week number
     * @param _performanceScores Array of performance scores
     * @param _ipfsHashes Array of IPFS image hashes
     */
    function mintWeeklyPlayerCards(
        uint256[] memory _playerIds,
        string[] memory _playerNames,
        uint256 _weekNumber,
        uint256[] memory _performanceScores,
        string[] memory _ipfsHashes
    ) external onlyRole(MINTER_ROLE) {
        require(
            !weeklyCardsMinted[_weekNumber],
            "Cards already minted for this week"
        );
        require(
            _playerIds.length <= MAX_CARDS_PER_WEEK && _playerIds.length > 0,
            "Invalid number of cards"
        );
        require(
            _playerIds.length == _playerNames.length &&
                _playerIds.length == _performanceScores.length &&
                _playerIds.length == _ipfsHashes.length,
            "Mismatched input arrays"
        );

        weeklyCardsMinted[_weekNumber] = true;

        for (uint256 i = 0; i < _playerIds.length; i++) {
            _mintPlayerCard(
                _playerIds[i],
                _playerNames[i],
                _weekNumber,
                _performanceScores[i],
                _ipfsHashes[i]
            );
        }
    }

    /**
     * Internal function to mint individual player cards
     */
    function _mintPlayerCard(
        uint256 _playerId,
        string memory _playerName,
        uint256 _weekNumber,
        uint256 _performanceScore,
        string memory _ipfsHash
    ) internal {
        uint256 newTokenId = ++_tokenIdCounter;

        _safeMint(msg.sender, newTokenId);

        playerCards[newTokenId] = PlayerCard({
            playerId: _playerId,
            playerName: _playerName,
            weekNumber: _weekNumber,
            performanceScore: _performanceScore,
            ipfsHash: _ipfsHash,
            mintedAt: block.timestamp,
            mintPrice: mintingPrice
        });

        emit PlayerCardMinted(
            newTokenId,
            _playerId,
            msg.sender,
            _playerName,
            _weekNumber,
            _performanceScore
        );
    }

    /**
     * List a player card for sale
     * @param _tokenId Token ID to list
     * @param _price Listing price
     */
    function listPlayerCard(uint256 _tokenId, uint256 _price) external {
        require(_exists(_tokenId), "Token does not exist");
        require(ownerOf(_tokenId) == msg.sender, "Not token owner");
        require(_price > 0, "Invalid price");

        // Approve marketplace to sell the token
        approve(address(this), _tokenId);

        emit PlayerCardListed(_tokenId, msg.sender, _price);
    }

    /**
     * Purchase a listed player card
     * @param _tokenId Token ID to purchase
     */
    function purchasePlayerCard(uint256 _tokenId) external payable {
        PlayerCard storage card = playerCards[_tokenId];
        require(_exists(_tokenId), "Token does not exist");

        uint256 salePrice = card.mintPrice;
        address seller = ownerOf(_tokenId);

        // Calculate platform fee
        uint256 platformFee = (salePrice * platformFeePercentage) / 100;
        uint256 sellerProceeds = salePrice - platformFee;

        // Transfer funds
        require(msg.value >= salePrice, "Insufficient payment");

        // Transfer platform fee
        payable(platformFeeReceiver).transfer(platformFee);

        // Transfer sale proceeds to seller
        payable(seller).transfer(sellerProceeds);

        // Transfer NFT
        _transfer(seller, msg.sender, _tokenId);

        // Update card price
        card.mintPrice = msg.value;

        emit PlayerCardSold(_tokenId, seller, msg.sender, salePrice);
    }

    /**
     * Get player card details
     * @param _tokenId Token ID to retrieve
     */
    function getPlayerCardDetails(
        uint256 _tokenId
    ) external view returns (PlayerCard memory) {
        require(_exists(_tokenId), "Token does not exist");
        return playerCards[_tokenId];
    }

    /**
     * Administrative functions
     */
    function updateMintingPrice(
        uint256 _newPrice
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        mintingPrice = _newPrice;
    }

    function updatePlatformFee(
        uint256 _newFeePercentage
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newFeePercentage <= 10, "Fee too high");
        platformFeePercentage = _newFeePercentage;
    }

    // Implement AccessControl and ERC165 interface support
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return
            ERC721Enumerable.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId);
    }
}
