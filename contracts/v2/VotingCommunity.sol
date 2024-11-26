// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

contract VotingCommunity {
    // Allows admins to create a poll for community input on various decisions
    function createPoll(string proposal);

    // Records user votes on proposals
    function castVote(address user, uint256 pollId, bool vote);

    // Shows the results of community voting for governance purposes
    function getPollResults(uint256 pollId) view returns (string);
}
