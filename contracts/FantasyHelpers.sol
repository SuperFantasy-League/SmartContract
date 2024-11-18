// SPDX-License Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract FantasyHelpers {
    event UserRegistered(address user);

    error InsufficientBalance();
    error PaymentFailed();
    error StringLengthZeroBytes();
    error UnauthorizedSender();
    error ZeroAddressDetected();
}
