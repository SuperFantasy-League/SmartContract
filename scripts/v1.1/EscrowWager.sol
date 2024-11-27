// SPDX-License Identifier: MIT
pragma solidity ^0.8.27

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WagerPlatform is Ownable, ReentrancyGuard {
    // Wager status enum
    enum WagerStatus {
        Created,
        Funded,
        Disputed,
        Resolved
    }

    // Struct to represent a wager
    struct Wager {
        address creator;
        address participant;
        address token;
        uint256 amount;
        WagerStatus status;
        address winner;
        uint256 createdAt;
    }

    // Platform fee percentage (e.g., 2%)
    uint256 public constant PLATFORM_FEE_PERCENTAGE = 2;

    // Mapping to store wagers
    mapping(uint256 => Wager) public wagers;
    uint256 public wagerCounter;

    // Platform fee collection address
    address public feeCollector;

    // Events
    event WagerCreated(uint256 indexed wagerId, address creator, uint256 amount, address token);
    event WagerFunded(uint256 indexed wagerId, address participant);
    event WagerResolved(uint256 indexed wagerId, address winner);
    event WagerDisputed(uint256 indexed wagerId);
    event FeesCollected(uint256 amount, address token);

    constructor(address _feeCollector) {
        feeCollector = _feeCollector;
    }

    /**
     * Create a new wager
     * @param _token Token address to use for wager
     * @param _amount Amount to wager
     */
    function createWager(address _token, uint256 _amount) external nonReentrant {
        require(_amount > 0, "Wager amount must be greater than 0");
        require(_token != address(0), "Invalid token address");

        // Transfer tokens from creator to contract
        IERC20 token = IERC20(_token);
        require(token.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        // Create new wager
        uint256 wagerId = wagerCounter++;
        wagers[wagerId] = Wager({
            creator: msg.sender,
            participant: address(0),
            token: _token,
            amount: _amount,
            status: WagerStatus.Created,
            winner: address(0),
            createdAt: block.timestamp
        });

        emit WagerCreated(wagerId, msg.sender, _amount, _token);
    }

    /**
     * Fund an existing wager
     * @param _wagerId Wager ID to fund
     */
    function fundWager(uint256 _wagerId) external nonReentrant {
        Wager storage wager = wagers[_wagerId];
        
        require(wager.status == WagerStatus.Created, "Wager not available");
        require(wager.participant == address(0), "Wager already funded");
        require(msg.sender != wager.creator, "Creator cannot fund own wager");

        // Transfer tokens from participant to contract
        IERC20 token = IERC20(wager.token);
        require(token.transferFrom(msg.sender, address(this), wager.amount), "Transfer failed");

        // Update wager details
        wager.participant = msg.sender;
        wager.status = WagerStatus.Funded;

        emit WagerFunded(_wagerId, msg.sender);
    }

    /**
     * Resolve a wager by declaring a winner
     * @param _wagerId Wager ID to resolve
     * @param _winner Address of the winner
     */
    function resolveWager(uint256 _wagerId, address _winner) external nonReentrant {
        Wager storage wager = wagers[_wagerId];
        
        require(wager.status == WagerStatus.Funded, "Wager not ready to resolve");
        require(
            msg.sender == wager.creator || 
            msg.sender == wager.participant, 
            "Only participants can resolve"
        );
        require(_winner == wager.creator || _winner == wager.participant, "Invalid winner");

        // Calculate platform fee
        uint256 totalAmount = wager.amount * 2;
        uint256 platformFee = (totalAmount * PLATFORM_FEE_PERCENTAGE) / 100;
        uint256 winnerAmount = totalAmount - platformFee;

        // Update wager status and winner
        wager.status = WagerStatus.Resolved;
        wager.winner = _winner;

        // Transfer tokens
        IERC20 token = IERC20(wager.token);
        require(token.transfer(_winner, winnerAmount), "Winner transfer failed");
        
        // Transfer platform fee
        require(token.transfer(feeCollector, platformFee), "Fee transfer failed");

        emit WagerResolved(_wagerId, _winner);
        emit FeesCollected(platformFee, wager.token);
    }

    /**
     * Dispute a wager if there's a disagreement
     * @param _wagerId Wager ID to dispute
     */
    function disputeWager(uint256 _wagerId) external nonReentrant {
        Wager storage wager = wagers[_wagerId];
        
        require(
            msg.sender == wager.creator || 
            msg.sender == wager.participant, 
            "Only participants can dispute"
        );
        require(wager.status == WagerStatus.Funded, "Wager not disputable");

        wager.status = WagerStatus.Disputed;
        emit WagerDisputed(_wagerId);
    }

    /**
     * Allow contract owner to resolve disputed wagers
     * @param _wagerId Wager ID to resolve
     * @param _winner Address of the winner
     */
    function adminResolveDispute(uint256 _wagerId, address _winner) external onlyOwner {
        Wager storage wager = wagers[_wagerId];
        
        require(wager.status == WagerStatus.Disputed, "Wager not in dispute");

        // Calculate platform fee
        uint256 totalAmount = wager.amount * 2;
        uint256 platformFee = (totalAmount * PLATFORM_FEE_PERCENTAGE) / 100;
        uint256 winnerAmount = totalAmount - platformFee;

        // Update wager status and winner
        wager.status = WagerStatus.Resolved;
        wager.winner = _winner;

        // Transfer tokens
        IERC20 token = IERC20(wager.token);
        require(token.transfer(_winner, winnerAmount), "Winner transfer failed");
        
        // Transfer platform fee
        require(token.transfer(feeCollector, platformFee), "Fee transfer failed");

        emit WagerResolved(_wagerId, _winner);
        emit FeesCollected(platformFee, wager.token);
    }

    /**
     * Update fee collector address
     * @param _newFeeCollector New fee collection address
     */
    function updateFeeCollector(address _newFeeCollector) external onlyOwner {
        require(_newFeeCollector != address(0), "Invalid fee collector");
        feeCollector = _newFeeCollector;
    }
}

contract EscrowPayment {


    // Allows users to deposit funds into their accounts for platform activities
    depositFunds(address user, uint256 amount)

    // Manages NFT purchases, holding funds in escrow until the transaction completes
    purchaseNFT(uint256 playerId, uint256 amount) payable

    // Releases payment after the purchase has been completed
    releasePayment(uint256 playerId, address seller)

    // Refunds users in case of disputes or unsuccessful transactions
    refundPayment(uint256 playerId, address buyer)

}