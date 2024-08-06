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

    // Struct to represent a transaction
    struct Transaction {
        address user;
        uint256 projectId;
        uint256 credits;
        string action; // "purchase", "retire", "transfer"
        uint256 timestamp;
    }

    // Struct to represent a reward
    struct Reward {
        uint256 rewardPoints;
        string badge;
    }

    // Mapping to store all registered projects
    mapping(uint256 => Project) public projects;
    uint256 public projectCount;

    // Mapping to store credits purchased by users
    mapping(address => mapping(uint256 => uint256)) public userCredits;

    // Mapping to store user rewards
    mapping(address => Reward) public userRewards;

    // Mapping to store transactions for each user
    mapping(address => Transaction[]) public userTransactions;

    // Array to store all transactions
    Transaction[] public allTransactions;

    // Mapping to store user reward points for leaderboard
    mapping(address => uint256) public userRewardPoints;

    // Badge thresholds
    uint256 public carbonChampionThreshold = 1000;
    uint256 public carbonContributorThreshold = 500;

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

    // Event emitted when a reward is earned
    event RewardEarned(address indexed user, uint256 rewardPoints, string badge);

    // Event emitted when badge thresholds are updated
    event BadgeThresholdUpdated(string badge, uint256 newThreshold);

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

        // Record transaction
        Transaction memory transaction = Transaction({
            user: msg.sender,
            projectId: _projectId,
            credits: _credits,
            action: "purchase",
            timestamp: block.timestamp
        });
        userTransactions[msg.sender].push(transaction);
        allTransactions.push(transaction);

        // Update user rewards
        _updateUserRewards(msg.sender, _credits, "purchase");

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

        // Record transaction
        Transaction memory transaction = Transaction({
            user: msg.sender,
            projectId: _projectId,
            credits: _credits,
            action: "retire",
            timestamp: block.timestamp
        });
        userTransactions[msg.sender].push(transaction);
        allTransactions.push(transaction);

        // Update user rewards
        _updateUserRewards(msg.sender, _credits, "retire");

        emit CreditsRetired(msg.sender, _projectId, _credits);
    }

    // Transfer carbon credits between users
    function transferCredits(address _to, uint256 _projectId, uint256 _credits) public payable {
        require(_projectId < projectCount, "Invalid project ID");
        require(userCredits[msg.sender][_projectId] >= _credits, "Insufficient credits to transfer");
        require(msg.value >= transferFee, "Insufficient fee for the transfer");

        // Deduct transfer fee from sender
        payable(owner).transfer(transferFee);

        // Perform credit transfer
        userCredits[msg.sender][_projectId] -= _credits;
        userCredits[_to][_projectId] += _credits;

        // Record transaction
        Transaction memory transaction = Transaction({
            user: msg.sender,
            projectId: _projectId,
            credits: _credits,
            action: "transfer",
            timestamp: block.timestamp
        });
        userTransactions[msg.sender].push(transaction);
        allTransactions.push(transaction);

        // Update user rewards
        _updateUserRewards(msg.sender, _credits, "transfer");

        emit CreditsTransferred(msg.sender, _to, _projectId, _credits);
    }

    // Function to update user rewards
    function _updateUserRewards(address _user, uint256 _credits, string memory) internal {
        Reward storage reward = userRewards[_user];

        // Example reward logic: 1 point per credit, with additional badges
        uint256 pointsEarned = _credits;
        reward.rewardPoints += pointsEarned;
        userRewardPoints[_user] = reward.rewardPoints;

        if (reward.rewardPoints >= carbonChampionThreshold) {
            reward.badge = "Carbon Champion";
        } else if (reward.rewardPoints >= carbonContributorThreshold) {
            reward.badge = "Carbon Contributor";
        } else {
            reward.badge = "Novice";
        }

        emit RewardEarned(_user, reward.rewardPoints, reward.badge);
    }

    // Function to retrieve all transactions
    function getAllTransactions() public view returns (Transaction[] memory) {
        return allTransactions;
    }

    // Function to retrieve user transactions
    function getUserTransactions(address _user) public view returns (Transaction[] memory) {
        return userTransactions[_user];
    }

    // Function to retrieve user rewards
    function getUserRewards(address _user) public view returns (Reward memory) {
        return userRewards[_user];
    }

    // Function to retrieve the leaderboard
    function getLeaderboard() public view returns (address[] memory, uint256[] memory) {
        uint256[] memory rewardPoints = new uint256[](projectCount);
        address[] memory users = new address[](projectCount);

        for (uint256 i = 0; i < projectCount; i++) {
            users[i] = projects[i].owner;
            rewardPoints[i] = userRewardPoints[projects[i].owner];
        }

        // Bubble sort to order users by reward points
        for (uint256 i = 0; i < rewardPoints.length - 1; i++) {
            for (uint256 j = i + 1; j < rewardPoints.length; j++) {
                if (rewardPoints[i] < rewardPoints[j]) {
                    (rewardPoints[i], rewardPoints[j]) = (rewardPoints[j], rewardPoints[i]);
                    (users[i], users[j]) = (users[j], users[i]);
                }
            }
        }

        return (users, rewardPoints);
    }

    // Function to update badge thresholds
    function updateBadgeThreshold(string memory _badge, uint256 _newThreshold) public {
        require(msg.sender == owner, "Only the owner can update badge thresholds");

        if (keccak256(abi.encodePacked(_badge)) == keccak256(abi.encodePacked("Carbon Champion"))) {
            carbonChampionThreshold = _newThreshold;
        } else if (keccak256(abi.encodePacked(_badge)) == keccak256(abi.encodePacked("Carbon Contributor"))) {
            carbonContributorThreshold = _newThreshold;
        } else {
            revert("Invalid badge type");
        }

        emit BadgeThresholdUpdated(_badge, _newThreshold);
    }
}
