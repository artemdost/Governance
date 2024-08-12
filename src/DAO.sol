// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "./Market.sol";

/// @title DAO Contract
/// @notice Implements a decentralized autonomous organization (DAO) with proposal and voting mechanisms.
/// @dev Inherits from the Market contract.
contract DAO is Market {
    
    /**
     * @notice Stores information about votes on a proposal.
     * @dev Tracks votes against, for, and abstain, along with a record of who has voted.
     */
    struct ProposalVote {
        uint againstVotes;
        uint forVotes;
        uint abstainVotes;
        mapping(address => bool) hasVoted;
    }

    /**
     * @notice Stores data about a proposal.
     * @dev Tracks the start and end times of voting and whether the proposal has been executed.
     */
    struct Proposal {
        uint votingStarts;
        uint votingEnds;
        bool executed;
    }

    /**
     * @notice Represents the different states a proposal can be in.
     */
    enum ProposalState {Pending, Active, Succeeded, Defeated, Executed, Expired}

    /**
     * @notice Maps a proposal ID to its corresponding Proposal struct.
     */
    mapping(bytes32 => Proposal) public proposals;

    /**
     * @notice Maps a proposal ID to its corresponding ProposalVote struct.
     */
    mapping(bytes32 => ProposalVote) public proposalVotes;
    
    /**
     * @notice The duration of the voting period, set to 14 days.
     */
    uint public constant VOTING_DURATION = 14 * 24 * 60 * 60; 

    /**
     * @notice The time limit for executing a proposal after it has succeeded, set to 7 days.
     */
    uint public constant TIME_TO_EXECUTE = 7 * 24 * 60 * 60;

    /**
     * @notice Sets the initial owner of the contract.
     * @param _addr The address to be set as the owner.
     */
    constructor(address _addr){
        owner = _addr;
    }

    /**
     * @notice Generates a new proposal for voting.
     * @dev Ensures that the proposal does not call the `unpause()` function and that it does not already exist.
     * @param _to The address to which the proposal's action will be directed.
     * @param _value The value of ETH or tokens to be transferred as part of the proposal.
     * @param _func The function signature of the proposal's action.
     * @param _data The data to be sent along with the function call.
     * @param _description A brief description of the proposal.
     */
    function propose(
        address _to,
        uint _value,
        string calldata _func,
        bytes calldata _data,
        string calldata _description
    ) external {
        if (keccak256(abi.encodePacked(_func)) == keccak256(abi.encodePacked("unpause()"))) revert("Can not be called there");

        bytes32 proposalId = generateProposalId(
            _to, _value, _func, _data, keccak256(bytes(_description))
        );

        require(proposals[proposalId].votingStarts == 0, "proposal already exists");

        proposals[proposalId] = Proposal({
            votingStarts: block.timestamp,
            votingEnds: block.timestamp + VOTING_DURATION,
            executed: false
        });
    }
    
    /**
     * @notice Executes a proposal that has passed the voting process.
     * @dev The proposal must be in the 'Succeeded' state, and the execution time must not have expired.
     * @param _to The address to which the proposal's action will be directed.
     * @param _value The value of ETH or tokens to be transferred as part of the proposal.
     * @param _func The function signature of the proposal's action.
     * @param _data The data to be sent along with the function call.
     * @param _descriptionHash The hash of the proposal's description.
     * @return bytes The response from the executed call.
     */
    function execute(
        address _to,
        uint _value,
        string calldata _func,
        bytes calldata _data,
        bytes32 _descriptionHash
    ) external returns(bytes memory) {
        bytes32 proposalId = generateProposalId(
            _to, _value, _func, _data, _descriptionHash
        );

        require(state(proposalId) == ProposalState.Succeeded, "invalid state");

        Proposal storage proposal = proposals[proposalId];

        require(proposal.votingEnds + TIME_TO_EXECUTE > block.timestamp, "the time for execution has expired");

        proposal.executed = true;

        bytes memory data;
        if (bytes(_func).length > 0) {
            data = abi.encodePacked(
                bytes4(keccak256(bytes(_func))), _data
            );
        } else {
            data = _data;
        }

        (bool success, bytes memory resp) = _to.call{value: _value}(data);
        require(success, "tx failed");

        return resp;
    }

    /**
     * @notice Calls the unpause function on a specified contract.
     * @dev The caller must hold governance tokens (govr).
     * @param _to The address of the contract to unpause.
     */
    function unpause(address _to) public {
        require(govr.balanceOf(msg.sender) > 0, "You are not part of the governament");
        (bool success, ) = _to.call(abi.encodeWithSignature("unpause()"));
        require(success);
    }

    /**
     * @notice Casts a vote on a proposal.
     * @dev The voting power is capped at 5000. The caller must have a sufficient token balance and must not have voted before.
     * @param proposalId The ID of the proposal to vote on.
     * @param voteType The type of vote (0 = Against, 1 = For, 2 = Abstain).
     */
    function vote(bytes32 proposalId, uint8 voteType) external {
        uint votingPower = govr.balanceOf(msg.sender);
        require(state(proposalId) == ProposalState.Active, "invalid state");
        require(votingPower > 0, "not enough tokens");
        if (votingPower > 5000) votingPower = 5000;

        ProposalVote storage proposalVote = proposalVotes[proposalId];

        require(!proposalVote.hasVoted[msg.sender], "already voted!");

        if (voteType == 0) {
            proposalVote.againstVotes += votingPower;
        } else if (voteType == 1) {
            proposalVote.forVotes += votingPower;
        } else {
            proposalVote.abstainVotes += votingPower;
        }

        proposalVote.hasVoted[msg.sender] = true;
    }

    /**
     * @notice Returns the current state of a proposal.
     * @param proposalId The ID of the proposal to check.
     * @return ProposalState The current state of the proposal.
     */
    function state(bytes32 proposalId) public view returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];
        ProposalVote storage proposalVote = proposalVotes[proposalId];

        require(proposal.votingStarts > 0, "proposal doesnt exist");

        if (proposal.executed) {
            return ProposalState.Executed;
        }

        if (block.timestamp < proposal.votingStarts) {
            return ProposalState.Pending;
        }

        if (block.timestamp >= proposal.votingStarts &&
            proposal.votingEnds > block.timestamp) {
            return ProposalState.Active;
        }

        if (proposalVote.forVotes > proposalVote.againstVotes) {
            return ProposalState.Succeeded;
        } else {
            return ProposalState.Defeated;
        }
    }

    /**
     * @notice Generates a unique ID for a proposal.
     * @param _to The address to which the proposal's action will be directed.
     * @param _value The value of ETH or tokens to be transferred as part of the proposal.
     * @param _func The function signature of the proposal's action.
     * @param _data The data to be sent along with the function call.
     * @param _descriptionHach The hash of the proposal's description.
     * @return bytes32 The generated proposal ID.
     */
    function generateProposalId(
        address _to,
        uint _value,
        string calldata _func,
        bytes calldata _data,
        bytes32 _descriptionHach
    ) public pure returns(bytes32) {
        return keccak256(abi.encode(_to, _value, _func, _data, _descriptionHach));
    }
}