# Evolve NP Fundraising Protocol

A fair-launch ERC-20 fundraising token protocol designed for nonprofit fundraising with an autonomous treasury that accumulates fees and manages liquidity. The Treasury executes:

- Hourly Liquidity Top-Up (POL): Monitors LP depth and tops up liquidity when below 5% of supply.

- Periodic Send & Burn: Monthly cycles where tokens are sent to a Donation Wallet and burned from Treasury, reducing supply and forwarding funds to the nonprofit.

- Donation Wallet converts tokens to a stable underlying asset (e.g., USDC) and forwards 100% of proceeds to the nonprofit's wallet.

The system uses Chainlink Automation for scheduled upkeep and enforces strict on-chain thresholds for safe, permissioned fund flow.

## Architecture Overview

- TreasuryWallet integrates with Chainlink Automation for liquidity health checks and periodic send-and-burn cycles.

- DonationWallet receives tokens from Treasury, integreates with Chainlink Automation for swaps fundraising tokens to the underlying asset, and forwards funds.

- FundRaisingToken: ERC20 token with minting to LP manager and treasury, and controlled burning by treasury.
- FundraisingTokenHook implements Uniswap V4 hook enforcing buy/sell tax, cooldowns, max buy limits, launch protection, and routing collected fees to treasury.

- Factory deploys wired instances of Token, Treasury, and Donation Wallets and manages pause/emergency control.

## Features

- Launch protection with cooldowns and max buy limits.

- Dynamic buy/sell taxation with fees routed to treasury.

- Chainlink Automation integration for periodic fund transfers and LP health adjustments.

- Emergency pause and withdrawal mechanisms.

- Liquidity pool health management via Uniswap V4 integration.

## Prerequisites

- Foundry (forge and cast)

- Solidity 0.8.26

- Node.js (optional, if you use scripts outside Foundry)

- Sepolia RPC URL and private key for deployment

- Etherscan API key for contract verification

## Installation
```
git clone git@github.com:EvolveNP/Smart-Contracts.git
cd Smart-Contracts
forge install
```

## Build

```
forge build
```

## Test

Run all tests with:
```
forge test --ffi --gas-report
```

## Coverage

```
forge coverage --ir-minimum
```

## Deployment & Verification

Make sure your environment variables are set in .env file, then source it:

```
source .env
```

Your .env should include:
```
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/your-infura-project-id
DEPLOYER_PRIVATE_KEY=your_private_key_here
ETHERSCAN_API_KEY=your_etherscan_api_key_here
```

### Verify Hook Contract

```
forge verify-contract <address> src/Hook.sol:FundraisingTokenHook --etherscan-api-key $ETHERSCAN_API_KEY --chain <chainName>
```

### Deploy & Verify Factory Contract

```
forge script --chain sepolia script/Factory.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast --verify -vvvv
```

### Deploy & Verify TreasuryWallet Contract

```
forge script --chain sepolia script/TreasuryWallet.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast --verify -vvvv
```

### Deploy & Verify DonationWallet Contract

```
forge script --chain sepolia script/DonationWallet.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast --verify -vvvv
```

## Usage

- Integrate the FundraisingTokenHook in Uniswap V4 PoolManager to enforce taxation and launch protection.

- Use TreasuryWallet with Chainlink Automation for automated upkeep tasks like transferring funds and adjusting liquidity.

- Use DonationWallet with Chainlink Automation for automated upkeep tasks linke swapping funds and sending to non profits organizations wallet.

- Emergency pause and withdrawal can be triggered by the Factory owner in case of issues.

## Security

- Only trusted contracts (Factory, Registry) can call critical functions.

- Taxation and transfer restrictions rely on tx.origin to identify users.

- Emergency pause halts critical operations during suspicious activities.