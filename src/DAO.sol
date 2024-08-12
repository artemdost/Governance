// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "./Market.sol";

contract DAO is Market{
    
    // информация о голосах в голосовалке
    struct ProposalVote{
        uint againstVotes;
        uint forVotes;
        bool abstainVotes;
        mapping(address => bool) hasVoted;
    }

    // данные голосовалки
    struct Proposal{
        uint votingStarts;
        uint votingEnds;
        bool executed;
    }

    // айди указывает на нужную структура данного голосования
    mapping(bytes32 => Proposal) public proposals;
    mapping(bytes32 => Proposal) public proposalsVotes;

    uint public constant VOTING_DELAY = 10;
    // 7 ДНЕЙ
    uint public constant VOTING_DURATION = 14 * 24 * 60 * 60; 

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

    // голосуем тут за предложение
    function vote(bytes32 proposalId, uint8 voteType) external {
        require(votingPower > 0, "not enough tokens");
        uint votingPower = token.balanceOf(msg.sender);
        if (votingPower > 5000) votingPower = 5000;

        ProposalVote storage proposalVote = proposalVotes[proposalId];

        require(!proposalVote.hasVoted[msg.sender], "already voted!");

        if (voteType == 0){
            proposalVote.againstVotes += votingPower;
        } else if (voteType == 1){
            proposalVote.fortVotes += votingPower;
        } else {
            proposalVote.abstaingVotes += votingPower;
        }
    }


    // генерит айди голосования
    function generateProposalId(
        address _to,
        uint _value,
        string calldata _func,
        bytes calldata _data,
        bytes32 calldata _descriptionHach
    ) internal pure returns(bytes32) {
        return keccak256(abi.encode(_to, _value, _func, _data, _descriptionHach));
    }
}