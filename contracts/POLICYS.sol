// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract InsurancePolicy is ERC721, Ownable {
    struct Policy {
        string name;
        uint256 cost;
        string description;
        bool exists;
    }

    struct PurchasedPolicy {
        uint256 policyId;
        string name;
        uint256 cost;
        string description;
        uint256 startDate;
        uint256 duration;
        bool isActive;
    }

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
    // uint256 public claimId = 0;

    constructor() ERC721("InsurancePolicyNFT", "IPNFT") Ownable(msg.sender) {}

    // Custom USDC token interface
    address constant MAINNET_USDC = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // USDC address in Base Sepolia Testnet
    IERC20 public usdcToken = IERC20(MAINNET_USDC); // USDC contract address

    function setUSDC(address _USDCaddress) external onlyOwner {
        usdcToken = IERC20(_USDCaddress);
    }

    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "Not an admin");
        _;
    }

    function isAdmin(address _address) public view returns (bool) {
        // Check if the address is the owner
        if (_address == owner()) {
            return true;
        }

        // Check if the address is in the admin list
        for (uint i = 0; i < adminList.length; i++) {
            if (adminList[i] == _address) {
                return true;
            }
        }
        return false;
    }

    function addAdmin(address _admin) external onlyOwner {
        adminList.push(_admin);
    }

    function removeAdmin(address _admin) external onlyOwner {
        for (uint i = 0; i < adminList.length; i++) {
            if (adminList[i] == _admin) {
                adminList[i] = adminList[adminList.length - 1];
                adminList.pop();
                break;
            }
        }
    }

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

    function removePolicy(uint256 _policyId) external onlyAdmin {
        delete policies[_policyId];
        emit PolicyRemoved(_policyId);
    }

    function buyPolicy(uint256 _policyId) external {
        Policy memory policy = policies[_policyId];
        require(policy.exists, "Policy does not exist");
        // require(msg.value == policy.cost, "Incorrect amount");

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

    function submitClaim(uint256 _policyId) external {
        require(policies[_policyId].exists, "Policy does not exist");
        require(
            (isAvailableSubmitClaim((msg.sender), _policyId)) == true,
            "Policy does not active"
        );
        claims.push(Claim(msg.sender, _policyId));
        emit ClaimSubmitted(msg.sender, _policyId);
    }
    function isAvailableSubmitClaim(
        address _address,
        uint256 _policyId
    ) private view returns (bool) {
        for (uint256 i = 0; i < purchasedPolicies[_address].length; i++) {
            PurchasedPolicy memory tmp = purchasedPolicies[_address][i];
            if (tmp.policyId == _policyId) {
                // Check if the policy has expired
                if (tmp.startDate + tmp.duration > block.timestamp) {
                    return true; // Policy is available for claim submission
                } else {
                    return false; // Policy is not available for claim submission
                }
            }
        }
        return false; // Policy ID not found
    }

    function approveClaim(uint256 _claimId) external onlyAdmin {
        require(_claimId < claims.length, "Claim does not exist"); // Check if claim exists

        address _buyer = claims[_claimId].sender; // Get the buyer's address
        uint256 _policyId = claims[_claimId].policyId; // Store the policyId before removing the claim

        // Transfer the cost to the buyer
        usdcToken.transfer(_buyer, policies[_policyId].cost);

        // Remove the purchased policy from the buyer's list
        _removePurchasedPolicy(_buyer, _policyId);
        // Remove the claim
        _removeClaim(_claimId, _buyer, _policyId, true);
    }

    function denyClaim(uint256 _claimId) external onlyAdmin {
        require(_claimId < claims.length, "Claim does not exist"); // Check if claim exists

        address _buyer = claims[_claimId].sender; // Get the buyer's address
        uint256 _policyId = claims[_claimId].policyId; // Store the policyId before removing the claim

        // Remove the claim
        _removeClaim(_claimId, _buyer, _policyId, false);
    }

    function _removePurchasedPolicy(address _buyer, uint256 _policyId) private {
        PurchasedPolicy[] storage policiesList = purchasedPolicies[_buyer];

        for (uint256 i = 0; i < policiesList.length; i++) {
            if (policiesList[i].policyId == _policyId) {
                // Replace the policy to be deleted with the last one and pop the last element
                policiesList[i] = policiesList[policiesList.length - 1];
                policiesList.pop();
                break; // Exit the loop after removing the policy
            }
        }
    }

    function _removeClaim(
        uint256 _claimId,
        address _buyer,
        uint256 _policyId,
        bool isApproved
    ) private {
        // Replace the claim to be deleted with the last claim and remove the last one
        claims[_claimId] = claims[claims.length - 1];
        claims.pop(); // Remove the last claim

        if (isApproved) {
            emit ClaimApproved(_buyer, _policyId); // Emit approval event
        } else {
            emit ClaimDenied(_buyer, _policyId); // Emit denial event
        }
    }

    function getActivePurchasedPolicies(
        address _buyer
    ) external view returns (PurchasedPolicy[] memory) {
        return purchasedPolicies[_buyer];
    }

    function getClaims() external view returns (Claim[] memory) {
        return claims;
    }
}
