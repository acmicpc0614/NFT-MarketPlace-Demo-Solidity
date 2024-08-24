// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract InsurancePolicy is ERC721, Ownable {
    /**
     * @dev Implementation of the {ERC721} interface.
     *
     * This is a smart contract that manages insurance policies and claims.
     */

    // This Policy struct serves as an interface for the model created by the admin.
    struct Policy {
        string name; // The name of the insurance policy.
        uint256 cost; // The cost of the insurance policy.
        string description; // A description of the insurance policy.
        bool exists; // A flag indicating whether the policy exists.
    }

    // This PurchasedPolicy struct serves as an interface for the model created by the User.
    struct PurchasedPolicy {
        uint256 policyId;
        string name; // The name of the insurance policy.
        uint256 cost; // The cost of the insurance policy.
        string description; // A description of the insurance policy.
        uint256 startDate;
        uint256 duration;
        bool isActive;
    }

    // This Claim struct serves as an interface for the model that user submit claim.
    struct Claim {
        address sender;
        uint256 policyId;
    }

    mapping(uint256 => Policy) public policies; // policyId => Policy
    mapping(address => PurchasedPolicy[]) public purchasedPolicies; // buyer => PurchasedPolicy[]

    Claim[] public claims; // List of claims
    uint256[] public activePolicies; // List of active policies
    address[] public adminList;

    event PolicyAdded(uint256 indexed policyId, string name, uint256 cost);
    event PolicyRemoved(uint256 indexed policyId);
    event PolicyPurchased(address indexed buyer, uint256 indexed policyId);
    event ClaimSubmitted(address indexed buyer, uint256 indexed policyId);
    event ClaimApproved(address indexed buyer, uint256 indexed policyId);
    event ClaimDenied(address indexed buyer, uint256 indexed policyId);

    uint256 public policyId = 0;

    constructor() ERC721("InsurancePolicyNFT", "IPNFT") Ownable(msg.sender) {}

    address constant MAINNET_USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // USDC address in Base Sepolia Testnet
    IERC20 public usdcToken = IERC20(MAINNET_USDC); // USDC contract address

    /**
     * @dev Set the USDC token address.
     * @param _USDCaddress The address of the USDC token contract.
     */
    function setUSDC(address _USDCaddress) external onlyOwner {
        usdcToken = IERC20(_USDCaddress);
    }

    /**
     * @dev Modifier to check if the caller is an admin.
     */
    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "Not an admin");
        _;
    }

    /**
     * @dev Check if an address is an admin.
     * @param _address The address to check.
     * @return bool True if the address is an admin, false otherwise.
     */
    function isAdmin(address _address) public view returns (bool) {
        if (_address == owner()) {
            return true;
        }
        for (uint i = 0; i < adminList.length; i++) {
            if (adminList[i] == _address) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Add a new admin.
     * @param _admin The address of the new admin.
     */
    function addAdmin(address _admin) external onlyOwner {
        adminList.push(_admin);
    }

    /**
     * @dev Remove an admin.
     * @param _admin The address of the admin to remove.
     */
    function removeAdmin(address _admin) external onlyOwner {
        for (uint i = 0; i < adminList.length; i++) {
            if (adminList[i] == _admin) {
                adminList[i] = adminList[adminList.length - 1];
                adminList.pop();
                break;
            }
        }
    }

    /**
     * @dev Add a new insurance policy.
     * @param _name The name of the policy.
     * @param _cost The cost of the policy.
     * @param _description A description of the policy.
     */
    function addPolicy(
        string memory _name,
        uint256 _cost,
        string memory _description
    ) external onlyAdmin {
        policies[policyId] = Policy(_name, _cost, _description, true);
        activePolicies.push(policyId);
        emit PolicyAdded(policyId, _name, _cost);
        policyId++;
    }

    /**
     * @dev Remove an existing insurance policy.
     * @param _policyId The ID of the policy to remove.
     */
    function removePolicy(uint256 _policyId) external onlyAdmin {
        delete policies[_policyId];
        emit PolicyRemoved(_policyId);
    }

    /**
     * @dev Purchase an insurance policy.
     * @param _policyId The ID of the policy to purchase.
     */
    function buyPolicy(uint256 _policyId) external {
        Policy memory policy = policies[_policyId];
        require(policy.exists, "Policy does not exist");

        purchasedPolicies[msg.sender].push(
            PurchasedPolicy(
                _policyId,
                policy.name,
                policy.cost,
                policy.description,
                block.timestamp,
                10,
                true
            )
        );

        usdcToken.transferFrom(msg.sender, address(this), policy.cost);
        emit PolicyPurchased(msg.sender, _policyId);
    }

    /**
     * @dev Submit a claim for a purchased policy.
     * @param _policyId The ID of the policy for which the claim is submitted.
     */
    function submitClaim(uint256 _policyId) external {
        require(policies[_policyId].exists, "Policy does not exist");
        require(
            (isAvailableSubmitClaim(msg.sender, _policyId) == true),
            "Policy does not active"
        );
        claims.push(Claim(msg.sender, _policyId));
        emit ClaimSubmitted(msg.sender, _policyId);
    }

    /**
     * @dev Check if a policy is available for claim submission.
     * @param _address The address of the buyer.
     * @param _policyId The ID of the policy to check.
     * @return bool True if the policy is available for claim submission, false otherwise.
     */
    function isAvailableSubmitClaim(
        address _address,
        uint256 _policyId
    ) private view returns (bool) {
        for (uint256 i = 0; i < purchasedPolicies[_address].length; i++) {
            PurchasedPolicy memory tmp = purchasedPolicies[_address][i];
            if (tmp.policyId == _policyId) {
                if (tmp.startDate + tmp.duration > block.timestamp) {
                    return true; // Policy is available for claim submission
                } else {
                    return false; // Policy is not available for claim submission
                }
            }
        }
        return false; // Policy ID not found
    }

    /**
     * @dev Approve a claim.
     * @param _claimId The ID of the claim to approve.
     */
    function approveClaim(uint256 _claimId) external onlyAdmin {
        require(_claimId < claims.length, "Claim does not exist");

        address _buyer = claims[_claimId].sender; // Get the buyer's address
        uint256 _policyId = claims[_claimId].policyId; // Store the policyId before removing the claim

        // Transfer the cost to the buyer
        usdcToken.transfer(_buyer, policies[_policyId].cost);

        // Remove the purchased policy from the buyer's list
        _removePurchasedPolicy(_buyer, _policyId);
        // Remove the claim
        _removeClaim(_claimId, _buyer, _policyId, true);
    }

    /**
     * @dev Deny a claim.
     * @param _claimId The ID of the claim to deny.
     */
    function denyClaim(uint256 _claimId) external onlyAdmin {
        require(_claimId < claims.length, "Claim does not exist");

        address _buyer = claims[_claimId].sender; // Get the buyer's address
        uint256 _policyId = claims[_claimId].policyId; // Store the policyId before removing the claim

        // Remove the claim
        _removeClaim(_claimId, _buyer, _policyId, false);
    }

    /**
     * @dev Remove a purchased policy from a buyer's list.
     * @param _buyer The address of the buyer.
     * @param _policyId The ID of the policy to remove.
     */
    function _removePurchasedPolicy(address _buyer, uint256 _policyId) private {
        PurchasedPolicy[] storage policiesList = purchasedPolicies[_buyer];

        for (uint256 i = 0; i < policiesList.length; i++) {
            if (policiesList[i].policyId == _policyId) {
                policiesList[i] = policiesList[policiesList.length - 1];
                policiesList.pop();
                break; // Exit the loop after removing the policy
            }
        }
    }

    /**
     * @dev Remove a claim from the claims list.
     * @param _claimId The ID of the claim to remove.
     * @param _buyer The address of the buyer.
     * @param _policyId The ID of the policy associated with the claim.
     * @param isApproved True if the claim was approved, false if denied.
     */
    function _removeClaim(
        uint256 _claimId,
        address _buyer,
        uint256 _policyId,
        bool isApproved
    ) private {
        claims[_claimId] = claims[claims.length - 1];
        claims.pop(); // Remove the last claim

        if (isApproved) {
            emit ClaimApproved(_buyer, _policyId); // Emit approval event
        } else {
            emit ClaimDenied(_buyer, _policyId); // Emit denial event
        }
    }

    /**
     * @dev Get all purchased policies of a buyer.
     * @param _buyer The address of the buyer.
     * @return PurchasedPolicy[] An array of purchased policies.
     */
    function getActivePurchasedPolicies(
        address _buyer
    ) external view returns (PurchasedPolicy[] memory) {
        return purchasedPolicies[_buyer];
    }

    /**
     * @dev Get all submitted claims.
     * @return Claim[] An array of claims.
     */
    function getClaims() external view returns (Claim[] memory) {
        return claims;
    }
}
