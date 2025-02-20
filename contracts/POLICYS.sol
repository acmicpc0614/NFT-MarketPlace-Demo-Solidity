// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract InsurancePolicy is ERC721, Ownable {
    struct Policy {
        uint256 amount; // Amount paid for the policy
        uint256 startDate; // Start date of the policy
        uint256 duration; // Duration in seconds
        bool isClaimed; // Claim status
        bool isExpired; // Expiration status
        string name; // Add the policy name field
    }

    mapping(uint256 => Policy) public policies;
    mapping(address => uint256[]) public userPolicies;

    uint256 public policyCounter;
    // uint256 public DURATION = 365 * 24 * 60 * 60;
    uint256 public DURATION = 10; // 10s

    // Custom USDC token interface
    address constant MAINNET_USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // USDC address in Base Sepolia Testnet
    IERC20 public usdcToken = IERC20(MAINNET_USDC); // USDC contract address
    // mapping(uint256 => string) public tokenURI;

    event PolicyPurchased(
        address indexed user,
        uint256 indexed policyId,
        uint256 amount
    );
    event ClaimSubmitted(uint256 indexed policyId);
    event ClaimApproved(uint256 indexed policyId);

    constructor() ERC721("InsurancePolicyNFT", "IPNFT") Ownable(msg.sender) {}

    function setUSDC(address _USDCaddress) external onlyOwner {
        usdcToken = IERC20(_USDCaddress);
    }

    function buyPolicy(
        string memory name,
        uint256 amount,
        uint256 duration
    ) external {
        require(amount > 0, "Amount must be greater than zero");

        // Transfer USDC tokens from the user to the contract
        usdcToken.transferFrom(msg.sender, address(this), amount);

        uint256 policyId = policyCounter++;

        policies[policyId] = Policy({
            amount: amount,
            startDate: block.timestamp,
            duration: duration,
            isClaimed: false,
            isExpired: false,
            name: name // Assign the policy name
        });

        _mint(msg.sender, policyId);
        userPolicies[msg.sender].push(policyId);

        emit PolicyPurchased(msg.sender, policyId, amount);
    }

    function submitClaim(uint256 policyId) external {
        require(checkExpiration(policyId) == true, "Expiration must be true");
        require(ownerOf(policyId) == msg.sender, "Not the policy owner");
        require(!policies[policyId].isClaimed, "Claim already submitted");
        require(!policies[policyId].isExpired, "Policy expired");

        policies[policyId].isClaimed = true;
        emit ClaimSubmitted(policyId);
    }

    function approveClaim(uint256 policyId) external onlyOwner {
        require(policies[policyId].isClaimed, "Claim not submitted");
        require(!policies[policyId].isExpired, "Policy expired");

        address _ownerId = ownerOf(policyId);

        // Returns token to buyer
        usdcToken.transfer(_ownerId, policies[policyId].amount);
        _burn(policyId);

        // Remove policy from policy list
        policies[policyId] = policies[policyCounter - 1];
        delete policies[policyCounter - 1];
        policyCounter--;

        // Remove policy from storage of UserPolicies
        uint256[] storage tmpUserPolicies = userPolicies[_ownerId];
        uint256 lengthOfTmp = tmpUserPolicies.length;
        for (uint256 i = 0; i < lengthOfTmp; i++) {
            if (tmpUserPolicies[i] == policyId) {
                tmpUserPolicies[i] = tmpUserPolicies[lengthOfTmp - 1]; // Move the last element into the deleted spot
                delete tmpUserPolicies[lengthOfTmp - 1];
                break;
            }
        }

        emit ClaimApproved(policyId);
    }

    function checkExpiration(uint256 policyId) public view returns (bool) {
        return
            block.timestamp >=
            policies[policyId].startDate + policies[policyId].duration;
    }

    function transferPolicy(address to, uint256 policyId) external {
        require(ownerOf(policyId) == msg.sender, "Not the policy owner");
        safeTransferFrom(msg.sender, to, policyId);
    }
}
