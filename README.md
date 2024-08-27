# Sample Bridge Contract

This project enables owner that can deploy bridge contract to Base Sepolia Chain and Holesky Chain.
And users can send custom ERC20 token from one chain to other chain by interacting with bridge contract.

# Deploy smart contract

npx hardhat run scripts/deploy_usdc.ts --network base_sepolia
npx hardhat verify --network base_sepolia 0xasd
