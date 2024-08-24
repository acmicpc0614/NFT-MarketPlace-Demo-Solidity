import { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";

let owner: any;
let buyer1: any;
let USDC: any;
let USDCAddress: any;
let NFT: any;
let NFTAddress: any;
const NFT_uri: string = "ipfs://MyCustomInsurancePolicy";
const DECIMAL = 0;
const DURATION = 10;
let START_TIME: number;

const NAME_1 = "first";
const NAME_2 = "second";

describe("Create Initial Contracts of all types", function () {
  START_TIME = Date.now();
  console.log("\t\tTest Start Time", START_TIME);
  it("get accounts", async function () {
    [owner, buyer1] = await ethers.getSigners();
    console.log("\tAccount address\t", await owner.getAddress());
  });

  it("should deploy USDC Contract", async function () {
    const instanceUSDC = await ethers.getContractFactory("USDCToken");
    USDC = await instanceUSDC.deploy();
    USDCAddress = await USDC.getAddress();
    console.log("\tUSDC Contract deployed at:", USDCAddress);
  });

  it("should deploy Policy Contract", async function () {
    const instanceNFT = await ethers.getContractFactory("InsurancePolicy");
    NFT = await instanceNFT.deploy();
    NFTAddress = await NFT.getAddress();
    console.log("\tPolicy Contract deployed at:", NFTAddress);
    await NFT.setUSDC(USDCAddress);
  });
});

describe("Send USDC to buyers", async function () {
  it("start distributing FeeToken", async function () {
    await USDC.transfer(buyer1.address, ethers.parseUnits("100", DECIMAL));
    expect(await USDC.balanceOf(buyer1.address)).to.equal(
      ethers.parseUnits("100", DECIMAL)
    );
    console.log("\tbuyer1 balance: " + (await USDC.balanceOf(buyer1)));
  });
});

describe("InsurancePolicy Contract", function () {
  it("should allow user to buy a policy", async function () {
    const amount = ethers.parseUnits("30", DECIMAL);
    const amount2 = ethers.parseUnits("50", DECIMAL);

    await USDC.connect(buyer1).approve(
      NFTAddress,
      ethers.parseUnits("100", DECIMAL)
    );
    // User buys a policy
    await NFT.connect(buyer1).buyPolicy(NAME_1, amount, DURATION);
    await NFT.connect(buyer1).buyPolicy(NAME_2, amount2, DURATION);

    // Check policy details
    const policy = await NFT.policies(0);
    expect(policy.amount).to.equal(amount);
    expect(policy.startDate).to.be.greaterThan(0);
    expect(policy.duration).to.equal(DURATION); // 1 year in seconds
    expect(policy.isClaimed).to.be.false;
    expect(policy.isExpired).to.be.false;
  });

  it("should allow user to submit a claim", async function () {
    // User submits a claim
    await ethers.provider.send("evm_increaseTime", [DURATION * 2]); // 20 s
    await ethers.provider.send("evm_mine"); // Mine the next block
    console.log("\t\tTime is flowing for test, 20s");
    await NFT.connect(buyer1).submitClaim(0);

    const policy = await NFT.policies(0);
    expect(policy.isClaimed).to.be.true;
  });

  it("should allow owner to approve a claim", async function () {
    // Owner approves the claim

    await NFT.connect(owner).approveClaim(0);
    const policy_2 = await NFT.policies(0);
    expect(policy_2.isExpired).to.be.false; // Ensure policy is not expired
    // Check that USDC has been transferred to buyer1
    const userBalance = await USDC.balanceOf(buyer1.address);
    expect(userBalance).to.equal(ethers.parseUnits("50", DECIMAL)); // 100 - 30 - 50 + 30 = 50
  });

  it("check Policies count", async function () {
    const count = await NFT.policyCounter();
    count === 1
      ? console.log("\t\tThere is still " + count + " policy.")
      : console.log("\t\tThere are still " + count + " policies.");

    for (let i = 0; i < count; i++) {
      const policy = await NFT.policies(i);
      console.log(`\t${i + 1}th policy: ` + policy.name + " " + policy.amount);
    }
  });

  it("check USDC balance", async function () {
    const SMBalance = await USDC.balanceOf(NFT);
    expect(SMBalance).to.equal(ethers.parseUnits("50", DECIMAL));

    console.log("\tContract balance: " + SMBalance);
    console.log("\tBuyer1 balance: " + (await USDC.balanceOf(buyer1)));

    console.log("\n\t\tTest End Time", Date.now());
    console.log("\t\tTest Duration", Date.now() - START_TIME, "ms");
  });
});
