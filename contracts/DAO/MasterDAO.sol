// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./utils/MasterDAOTools.sol";

contract MasterDAO is NounsDAOStorageV1, NounsDAOEvents {
    uint256 public constant MIN_PROPOSAL_THRESHOLD_BPS = 1; // 1 basis point or 0.01%

    uint256 public constant MAX_PROPOSAL_THRESHOLD_BPS = 1_000; // 1,000 basis points or 10%

    uint256 public constant MIN_VOTING_PERIOD = 5_760; // About 24 hours

    uint256 public constant MAX_VOTING_PERIOD = 80_640; // About 2 weeks

    uint256 public constant MIN_VOTING_DELAY = 1;

    uint256 public constant MAX_VOTING_DELAY = 40_320; // About 1 week

    uint256 public constant MIN_QUORUM_VOTES_BPS = 200; // 200 basis points or 2%

    uint256 public constant MAX_QUORUM_VOTES_BPS = 2_000; // 2,000 basis points or 20%

    uint256 public constant proposalMaxOperations = 10; // 10 actions

    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,uint256 chainId,address verifyingContract)"
        );

    bytes32 public constant BALLOT_TYPEHASH =
        keccak256("Ballot(uint256 proposalId,uint8 support)");

    struct ProposalTemp {
        uint256 totalSupply;
        uint256 proposalThreshold;
        uint256 latestProposalId;
        uint256 startBlock;
        uint256 endBlock;
    }

    function initialize(
        address timelock_,
        address nouns_,
        address vetoer_,
        uint256 votingPeriod_,
        uint256 votingDelay_,
        uint256 proposalThresholdBPS_,
        uint256 quorumVotesBPS_
    ) public virtual {
        // require(
        //     address(timelock) == address(0),
        //     "NounsDAO::initialize: can only initialize once"
        // );
        // require(msg.sender == admin, "NounsDAO::initialize: admin only");
        // require(
        //     timelock_ != address(0),
        //     "NounsDAO::initialize: invalid timelock address"
        // );
        // require(
        //     nouns_ != address(0),
        //     "NounsDAO::initialize: invalid nouns address"
        // );
        // require(
        //     votingPeriod_ >= MIN_VOTING_PERIOD &&
        //         votingPeriod_ <= MAX_VOTING_PERIOD,
        //     "NounsDAO::initialize: invalid voting period"
        // );
        // require(
        //     votingDelay_ >= MIN_VOTING_DELAY &&
        //         votingDelay_ <= MAX_VOTING_DELAY,
        //     "NounsDAO::initialize: invalid voting delay"
        // );
        // require(
        //     proposalThresholdBPS_ >= MIN_PROPOSAL_THRESHOLD_BPS &&
        //         proposalThresholdBPS_ <= MAX_PROPOSAL_THRESHOLD_BPS,
        //     "NounsDAO::initialize: invalid proposal threshold"
        // );
        // require(
        //     quorumVotesBPS_ >= MIN_QUORUM_VOTES_BPS &&
        //         quorumVotesBPS_ <= MAX_QUORUM_VOTES_BPS,
        //     "NounsDAO::initialize: invalid proposal threshold"
        // );

        emit VotingPeriodSet(votingPeriod, votingPeriod_);
        emit VotingDelaySet(votingDelay, votingDelay_);
        emit ProposalThresholdBPSSet(
            proposalThresholdBPS,
            proposalThresholdBPS_
        );
        emit QuorumVotesBPSSet(quorumVotesBPS, quorumVotesBPS_);

        timelock = INounsDAOExecutor(timelock_);
        nouns = NounsTokenLike(nouns_);
        vetoer = vetoer_;
        votingPeriod = votingPeriod_;
        votingDelay = votingDelay_;
        proposalThresholdBPS = proposalThresholdBPS_;
        quorumVotesBPS = quorumVotesBPS_;
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    ) public returns (uint256) {
        ProposalTemp memory temp;

        temp.totalSupply = nouns.totalSupply();

        temp.proposalThreshold = bps2Uint(
            proposalThresholdBPS,
            temp.totalSupply
        );

        require(
            nouns.getPriorVotes(msg.sender, block.number - 1) >=
                temp.proposalThreshold,
            "NounsDAO::propose: proposer votes below proposal threshold"
        );
        // require(
        //     targets.length == values.length &&
        //         targets.length == signatures.length &&
        //         targets.length == calldatas.length,
        //     "NounsDAO::propose: proposal function information arity mismatch"
        // );
        require(targets.length != 0, "NounsDAO::propose: must provide actions");
        require(
            targets.length <= proposalMaxOperations,
            "NounsDAO::propose: too many actions"
        );

        temp.latestProposalId = latestProposalIds[msg.sender];
        if (temp.latestProposalId != 0) {
            ProposalState proposersLatestProposalState = state(
                temp.latestProposalId
            );
            require(
                proposersLatestProposalState != ProposalState.Active,
                "NounsDAO::propose: one live proposal per proposer, found an already active proposal"
            );
            require(
                proposersLatestProposalState != ProposalState.Pending,
                "NounsDAO::propose: one live proposal per proposer, found an already pending proposal"
            );
        }

        temp.startBlock = block.number + votingDelay;
        temp.endBlock = temp.startBlock + votingPeriod;

        proposalCount++;
        Proposal storage newProposal = proposals[proposalCount];

        newProposal.id = proposalCount;
        newProposal.proposer = msg.sender;
        newProposal.proposalThreshold = temp.proposalThreshold;
        newProposal.quorumVotes = bps2Uint(quorumVotesBPS, temp.totalSupply);
        newProposal.eta = 0;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.signatures = signatures;
        newProposal.calldatas = calldatas;
        newProposal.startBlock = temp.startBlock;
        newProposal.endBlock = temp.endBlock;
        newProposal.forVotes = 0;
        newProposal.againstVotes = 0;
        newProposal.abstainVotes = 0;
        newProposal.canceled = false;
        newProposal.executed = false;
        newProposal.vetoed = false;

        latestProposalIds[newProposal.proposer] = newProposal.id;

        return newProposal.id;
    }

    function state(uint256 proposalId) public view returns (ProposalState) {
        require(
            proposalCount >= proposalId,
            "NounsDAO::state: invalid proposal id"
        );
        Proposal storage proposal = proposals[proposalId];
        if (proposal.vetoed) {
            return ProposalState.Vetoed;
        } else if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (
            proposal.forVotes <= proposal.againstVotes ||
            proposal.forVotes < proposal.quorumVotes
        ) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= proposal.eta + timelock.GRACE_PERIOD()) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    function bps2Uint(uint256 bps, uint256 number)
        internal
        pure
        returns (uint256)
    {
        return (number * bps) / 10000;
    }
}
