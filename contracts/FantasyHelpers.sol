// SPDX-License Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract FantasyHelpers is AccessControl {
    event TeamCreated(address indexed user, );
    event TeamUpdated(address indexed user, uint256[] playerIds, uint256 totalValue);

    event UserRegistered(address user);

    error ();

    error InsufficientBalance();
    error PaymentFailed();
    error StringLengthZeroBytes();
    error UnauthorizedSender();
    error ZeroAddressDetected();



    function _onlyAdmin() internal view {
        require(msg.sender == admin, UnauthorizedSender());
    }

    function checkZeroAddress() internal view {
        require(msg.sender != address(0), ZeroAddressDetected());
    }
}
