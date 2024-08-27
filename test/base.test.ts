import { ethers } from "hardhat";
import { expect } from "chai";

let owner: any;
let buyer1: any;
let buyer2: any;
let USDC: any;
let USDCAddress: any;
let insurancePolicy: any;
let insurancePolicyAddress: any;
const NFT_uri: string = "ipfs://MyCustomInsurancePolicy";
const DECIMAL = 6;
const DURATION = 10;
let START_TIME: number;

describe("Create Initial Contracts of all types", function () {
  START_TIME = Date.now();
  console.log("\t\tTest Start Time", START_TIME);
  it("get accounts", async function () {
    [owner, buyer1, buyer2] = await ethers.getSigners();
    console.log("\tAccount address\t", await owner.getAddress());
  });

  it("should deploy USDC Contract", async function () {
    const instanceUSDC = await ethers.getContractFactory("USDCToken");
    USDC = await instanceUSDC.deploy();
    USDCAddress = await USDC.getAddress();
    console.log("\tUSDC Contract deployed at:", USDCAddress);
  });

  it("should deploy Policy Contract", async function () {
    const InsurancePolicy = await ethers.getContractFactory("InsurancePolicy");
    insurancePolicy = await InsurancePolicy.deploy();
    // await insurancePolicy.deployed();

    insurancePolicyAddress = await insurancePolicy.getAddress();
    console.log("\tPolicy Contract deployed at:", insurancePolicyAddress);
    await insurancePolicy.setUSDC(USDCAddress);
  });
});

describe("Send USDC to buyers", async function () {
  it("start distributing FeeToken", async function () {
    await USDC.transfer(buyer1.address, ethers.parseUnits("100", DECIMAL));
    await USDC.transfer(buyer2.address, ethers.parseUnits("200", DECIMAL));

    expect(await USDC.balanceOf(buyer1.address)).to.equal(
      ethers.parseUnits("100", DECIMAL)
    );
    expect(await USDC.balanceOf(buyer2.address)).to.equal(
      ethers.parseUnits("200", DECIMAL)
    );

    const SMBalance = await USDC.balanceOf(insurancePolicy);
    console.log("\tContract balance: " + SMBalance);
    console.log("\tbuyer1 balance: " + (await USDC.balanceOf(buyer1)));
    console.log("\tbuyer2 balance: " + (await USDC.balanceOf(buyer2)));
  });
});

describe("InsurancePolicy Contract", function () {
  it("should allow owner to add buyer1 as admin", async function () {
    await insurancePolicy.addAdmin(buyer1.address);
    expect(await insurancePolicy.isAdmin(buyer1.address)).to.be.true;
  });

  it("should allow owner to add a policy 'O1'", async function () {
    const amount = ethers.parseUnits("10", DECIMAL);
    await insurancePolicy.addPolicy("O1", amount, "Description of O1");
    const policy = await insurancePolicy.policies(0);
    expect(policy.name).to.equal("O1");
    expect(policy.cost).to.equal(amount);
    expect(policy.description).to.equal("Description of O1");
  });

  it("should allow buyer1 to add a policy 'B1'", async function () {
    const amount = ethers.parseUnits("5", DECIMAL);
    await insurancePolicy
      .connect(buyer1)
      .addPolicy("B1", amount, "Description of B1");
    const policy = await insurancePolicy.policies(1);
    expect(policy.name).to.equal("B1");
    expect(policy.cost).to.equal(amount);
    expect(policy.description).to.equal("Description of B1");
  });

  it("should allow buyer2 to buy policy 'O1'", async function () {
    await USDC.connect(buyer2).approve(
      insurancePolicyAddress,
      ethers.parseUnits("100", DECIMAL)
    );
    await insurancePolicy.connect(buyer2).buyPolicy(0);

    const purchasedPolicies = await insurancePolicy.getActivePurchasedPolicies(
      buyer2.address
    );
    expect(purchasedPolicies.length).to.equal(1);
    expect(purchasedPolicies[0].name).to.equal("O1");
  });

  it("should allow buyer2 to buy policy 'B1'", async function () {
    await insurancePolicy.connect(buyer2).buyPolicy(1);

    const purchasedPolicies = await insurancePolicy.getActivePurchasedPolicies(
      buyer2.address
    );
    expect(purchasedPolicies.length).to.equal(2);
    expect(purchasedPolicies[1].name).to.equal("B1");
  });

  it("should allow buyer2 to submit a claim for a policy", async function () {
    await insurancePolicy.connect(buyer2).submitClaim(0);
    // await ethers.provider.send("evm_increaseTime", [DURATION * 2]); // 20 s
    // await ethers.provider.send("evm_mine"); // Mine the next block
    // console.log("\t\tTime is flowing for test, 20s");
    await insurancePolicy.connect(buyer2).submitClaim(1);

    const claims = await insurancePolicy.getClaims();
    expect(claims.length).to.equal(2);
    expect(claims[0].sender).to.equal(buyer2.address);
    expect(claims[0].policyId).to.equal(0);
  });

  it("should allow buyer1 to approve buyer2's claim", async function () {
    await insurancePolicy.connect(buyer1).approveClaim(0);
    const claims = await insurancePolicy.getClaims();
    expect(claims.length).to.equal(1); // Claim should be removed after approval
  });

  it("should allow buyer1 to deny buyer2's claim", async function () {
    await insurancePolicy.connect(buyer1).denyClaim(0);
    const claims = await insurancePolicy.getClaims();
    expect(claims.length).to.equal(0); // Claim should be removed after denial
  });

  it("should remove policy from owner", async function () {
    await insurancePolicy.removePolicy(0);
    const policies = await insurancePolicy.getActivePurchasedPolicies(buyer2);
    expect(policies.length).to.equal(1); // Policy should be removed after removal by owner
  });

  it("check USDC balance", async function () {
    const SMBalance = await USDC.balanceOf(insurancePolicy);
    expect(SMBalance).to.equal(ethers.parseUnits("5", DECIMAL)); // 10 + 5 - 10

    console.log("\tContract balance: " + SMBalance);
    console.log("\tBuyer1 balance: " + (await USDC.balanceOf(buyer1)));
    console.log("\tBuyer2 balance: " + (await USDC.balanceOf(buyer2))); // 200 - 10 - 50 + 10
    console.log("\n\t\tTest End Time", Date.now());
    console.log("\t\tTest Duration", Date.now() - START_TIME, "ms");
  });
});
