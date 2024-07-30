// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CarbonOffsetMarketplace {
    address public owner;
    uint256 public feePercentage = 100; // Fee percentage in basis points (e.g., 1% = 100 basis points)
    bool public allowNonOwnerRegistration = false; // Flag to allow/disallow non-owners to register projects
    uint256 public minVotesForProposal = 1; // Minimum votes required for a proposal to be executed
    uint256 public transferFee = 2 ether; // Fixed fee for credit transfers

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

    // Event emitted when a project is updated
    event ProjectUpdated(uint256 projectId, string name, uint256 totalCredits, uint256 pricePerCredit);

    // Event emitted when credits are purchased
    event CreditsPurchased(address indexed buyer, uint256 projectId, uint256 credits);

    // Event emitted when credits are retired
    event CreditsRetired(address indexed user, uint256 projectId, uint256 credits);

    // Event emitted when credits are transferred
    event CreditsTransferred(address indexed from, address indexed to, uint256 projectId, uint256 credits);

    // Event emitted when a new proposal is created
    event ProposalCreated(uint256 proposalId, string description, address proposer);

    // Event emitted when a vote is cast
    event VoteCast(uint256 proposalId, address voter, bool support);

    // Event emitted when a proposal is executed
    event ProposalExecuted(uint256 proposalId);

    constructor() {
        owner = msg.sender;
    }

    // Toggle registration by non-owners
    function toggleNonOwnerRegistration(bool _allow) public {
        require(msg.sender == owner, "Only the owner can toggle registration permissions");
        allowNonOwnerRegistration = _allow;
    }

    // Set minimum votes required for a proposal to be executed
    function setMinVotesForProposal(uint256 _minVotes) public {
        require(msg.sender == owner, "Only the owner can set minimum votes");
        minVotesForProposal = _minVotes;
    }

    // Register a new Carbon Offset Project
    function registerProject(string memory _name, uint256 _totalCredits, uint256 _pricePerCredit) public {
        require(
            msg.sender == owner || allowNonOwnerRegistration,
            "Only the owner can register projects and non-owners are not allowed"
        );
        require(bytes(_name).length > 0, "Project name cannot be empty");
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

    // Update an existing Carbon Offset Project
    function updateProject(uint256 _projectId, string memory _name, uint256 _totalCredits, uint256 _pricePerCredit) public {
        require(_projectId < projectCount, "Invalid project ID");
        Project storage project = projects[_projectId];
        require(msg.sender == project.owner, "Only the project owner can update the project");
        require(bytes(_name).length > 0, "Project name cannot be empty");
        require(_totalCredits > 0, "Total credits should be greater than zero");
        require(_pricePerCredit > 0, "Price per credit should be greater than zero");

        project.name = _name;
        project.totalCredits = _totalCredits;
        project.availableCredits = _totalCredits;
        project.pricePerCredit = _pricePerCredit;

        emit ProjectUpdated(_projectId, _name, _totalCredits, _pricePerCredit);
    }

    // Purchase carbon credits from a project
    function purchaseCredits(uint256 _projectId, uint256 _credits) public payable {
        require(_projectId < projectCount, "Invalid project ID");
        Project storage project = projects[_projectId];
        require(_credits > 0, "Credits should be greater than zero");
        require(_credits <= project.availableCredits, "Not enough available credits");
        uint256 totalPrice = _credits * project.pricePerCredit;
        require(msg.value >= totalPrice, "Insufficient payment");

        uint256 fee = (totalPrice * feePercentage) / 10000; // Calculate fee
        uint256 paymentToOwner = totalPrice - fee;

        project.availableCredits -= _credits;
        userCredits[msg.sender][_projectId] += _credits;
        userReputation[msg.sender] += _credits; // Increase user's reputation points

        // Transfer payment to project owner
        payable(project.owner).transfer(paymentToOwner);

        // Transfer fee to contract owner
        payable(owner).transfer(fee);

        emit CreditsPurchased(msg.sender, _projectId, _credits);
    }

    // Retire purchased credits to offset carbon
    function retireCredits(uint256 _projectId, uint256 _credits) public {
        require(_projectId < projectCount, "Invalid project ID");
        require(userCredits[msg.sender][_projectId] >= _credits, "Insufficient credits to retire");

        userCredits[msg.sender][_projectId] -= _credits;
        emit CreditsRetired(msg.sender, _projectId, _credits);
    }

    // Transfer carbon credits between users
    function transferCredits(address _to, uint256 _projectId, uint256 _credits) public payable {
        require(_projectId < projectCount, "Invalid project ID");
        require(userCredits[msg.sender][_projectId] >= _credits, "Insufficient credits to transfer");
        require(msg.value >= transferFee, "Insufficient fee for the transfer");

        uint256 totalCredits = userCredits[msg.sender][_projectId];
        require(totalCredits >= _credits, "Insufficient credits for transfer");

        // Deduct transfer fee from sender
        payable(owner).transfer(transferFee);

        // Perform credit transfer
        userCredits[msg.sender][_projectId] -= _credits;
        userCredits[_to][_projectId] += _credits;

        emit CreditsTransferred(msg.sender, _to, _projectId, _credits);
    }

    // Get project details
    function getProject(uint256 _projectId) public view returns (string memory, uint256, uint256, uint256, address) {
        require(_projectId < projectCount, "Invalid project ID");
        Project storage project = projects[_projectId];
        return (project.name, project.totalCredits, project.availableCredits, project.pricePerCredit, project.owner);
    }

    // Get user's credits for a specific project
    function getUserCredits(address _user, uint256 _projectId) public view returns (uint256) {
        require(_projectId < projectCount, "Invalid project ID");
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

    // Create a new proposal
    function createProposal(string memory _description) public {
        require(msg.sender == owner, "Only the owner can create proposals");
        require(bytes(_description).length > 0, "Proposal description cannot be empty");

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
        require(_proposalId < proposals.length, "Invalid proposal ID");
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
        require(msg.sender == owner, "Only the owner can execute proposals");
        require(_proposalId < proposals.length, "Invalid proposal ID");
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.executed, "Proposal already executed");
        require(proposal.votesFor >= minVotesForProposal, "Proposal did not meet the minimum votes required");

        // Add your proposal execution logic here

        proposal.executed = true;
        emit ProposalExecuted(_proposalId);
    }
}
