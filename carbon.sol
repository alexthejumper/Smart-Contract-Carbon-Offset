// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CarbonOffsetMarketplace {
    // Struct to represent a Carbon Offset Project
    struct Project {
        address owner;
        string name;
        uint256 totalCredits;
        uint256 availableCredits;
        uint256 pricePerCredit;
    }

    // Mapping to store all registered projects
    mapping(uint256 => Project) public projects;
    uint256 public projectCount;

    // Mapping to store credits purchased by users
    mapping(address => mapping(uint256 => uint256)) public userCredits;

    // Mapping to store user reputation points
    mapping(address => uint256) public userReputation;

    // Event emitted when a new project is registered
    event ProjectRegistered(uint256 projectId, string name, uint256 totalCredits, uint256 pricePerCredit);

    // Event emitted when credits are purchased
    event CreditsPurchased(address indexed buyer, uint256 projectId, uint256 credits);

    // Event emitted when credits are retired
    event CreditsRetired(address indexed user, uint256 projectId, uint256 credits);

    // Register a new Carbon Offset Project
    function registerProject(string memory _name, uint256 _totalCredits, uint256 _pricePerCredit) public {
        require(_totalCredits > 0, "Total credits should be greater than zero");
        require(_pricePerCredit > 0, "Price per credit should be greater than zero");

        projects[projectCount] = Project({
            owner: msg.sender,
            name: _name,
            totalCredits: _totalCredits,
            availableCredits: _totalCredits,
            pricePerCredit: _pricePerCredit
        });

        emit ProjectRegistered(projectCount, _name, _totalCredits, _pricePerCredit);
        projectCount++;
    }

    // Purchase carbon credits from a project
    function purchaseCredits(uint256 _projectId, uint256 _credits) public payable {
        Project storage project = projects[_projectId];
        require(_credits > 0, "Credits should be greater than zero");
        require(_credits <= project.availableCredits, "Not enough available credits");
        require(msg.value >= _credits * project.pricePerCredit, "Insufficient payment");

        project.availableCredits -= _credits;
        userCredits[msg.sender][_projectId] += _credits;
        userReputation[msg.sender] += _credits; // Increase user's reputation points

        // Transfer payment to project owner
        payable(project.owner).transfer(msg.value);

        emit CreditsPurchased(msg.sender, _projectId, _credits);
    }

    // Retire purchased credits to offset carbon
    function retireCredits(uint256 _projectId, uint256 _credits) public {
        require(userCredits[msg.sender][_projectId] >= _credits, "Insufficient credits to retire");

        userCredits[msg.sender][_projectId] -= _credits;
        emit CreditsRetired(msg.sender, _projectId, _credits);
    }

    // Get project details
    function getProject(uint256 _projectId) public view returns (string memory, uint256, uint256, uint256, address) {
        Project storage project = projects[_projectId];
        return (project.name, project.totalCredits, project.availableCredits, project.pricePerCredit, project.owner);
    }

    // Get user's credits for a specific project
    function getUserCredits(address _user, uint256 _projectId) public view returns (uint256) {
        return userCredits[_user][_projectId];
    }

    // Get user's reputation points
    function getUserReputation(address _user) public view returns (uint256) {
        return userReputation[_user];
    }

    // Governance: Allows users to vote on project proposals
    struct Proposal {
        address proposer;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
    }

    Proposal[] public proposals;

    // Event emitted when a new proposal is created
    event ProposalCreated(uint256 proposalId, string description, address proposer);

    // Event emitted when a vote is cast
    event VoteCast(uint256 proposalId, address voter, bool support);

    // Create a new proposal
    function createProposal(string memory _description) public {
        proposals.push(Proposal({
            proposer: msg.sender,
            description: _description,
            votesFor: 0,
            votesAgainst: 0,
            executed: false
        }));

        emit ProposalCreated(proposals.length - 1, _description, msg.sender);
    }

    // Vote on a proposal
    function voteOnProposal(uint256 _proposalId, bool _support) public {
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.executed, "Proposal already executed");

        if (_support) {
            proposal.votesFor++;
        } else {
            proposal.votesAgainst++;
        }

        emit VoteCast(_proposalId, msg.sender, _support);
    }

    // Execute a proposal if it has enough votes
    function executeProposal(uint256 _proposalId) public {
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(proposal.votesFor > proposal.votesAgainst, "Proposal did not pass");

        // Add your proposal execution logic here

        proposal.executed = true;
    }
}
