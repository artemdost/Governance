// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "./Market.sol";

contract DAO is Market{
    
    // информация о голосах в голосовалке
    struct ProposalVote{
        uint againstVotes;
        uint forVotes;
        uint abstainVotes;
        mapping(address => bool) hasVoted;
    }

    // данные голосовалки
    struct Proposal{
        uint votingStarts;
        uint votingEnds;
        bool executed;
    }

    enum ProposalState {Pending, Active, Succeeded, Defeated, Executed, Expired}

    // айди указывает на нужную структура данного голосования
    mapping(bytes32 => Proposal) public proposals;
    mapping(bytes32 => ProposalVote) public proposalVotes;

    uint public constant VOTING_DELAY = 10;
    // 7 ДНЕЙ
    uint public constant VOTING_DURATION = 14 * 24 * 60 * 60; 
    uint public constant TIME_TO_EXECUTE = 7 * 24 * 60 * 60;

    // устанавливает владельца
    constructor(address _addr){
        owner = _addr;
    }

    // тут мы генерим предложение
    function propose(
        address _to,
        uint _value,
        string calldata _func,
        bytes calldata _data,
        string calldata _description
    ) external {
        require(govr.balanceOf(msg.sender) > 0, "not enough tokens");

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
    
    // выполняем действие за которое проголосовали
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

        require(proposal.votingEnds + TIME_TO_EXECUTE < block.timestamp, "the time for execution has expired");

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

    // голосуем тут за предложение
    function vote(bytes32 proposalId, uint8 voteType) external {
        uint votingPower = govr.balanceOf(msg.sender);
        require(state(proposalId) == ProposalState.Active, "invalid state");
        require(votingPower > 0, "not enough tokens");
        if (votingPower > 5000) votingPower = 5000;

        ProposalVote storage proposalVote = proposalVotes[proposalId];

        require(!proposalVote.hasVoted[msg.sender], "already voted!");

        if (voteType == 0){
            proposalVote.againstVotes += votingPower;
        } else if (voteType == 1){
            proposalVote.forVotes += votingPower;
        } else {
            proposalVote.abstainVotes += votingPower;
        }

        proposalVote.hasVoted[msg.sender] = true;
    }


    // возвращает состояние
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

        if(block.timestamp >= proposal.votingStarts &&
            proposal.votingEnds > block.timestamp) {
            return ProposalState.Active;
        }

        if(proposalVote.forVotes > proposalVote.againstVotes) {
            return ProposalState.Succeeded;
        } else {
            return ProposalState.Defeated;
        }
    }

    // генерит айди голосования
    function generateProposalId(
        address _to,
        uint _value,
        string calldata _func,
        bytes calldata _data,
        bytes32 _descriptionHach
    ) internal pure returns(bytes32) {
        return keccak256(abi.encode(_to, _value, _func, _data, _descriptionHach));
    }
}