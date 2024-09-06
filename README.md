# PrizePot
# 🏆 PrizePot Token Contract (PPOT)

## Overview
The **PrizePot Token** (PPOT) is an ERC-20 compliant cryptocurrency that includes community-driven governance for tax fees and blacklisting, automatic liquidity management, slippage protection, and enhanced vesting mechanisms. This smart contract ensures transparency, security, and fair tokenomics to maintain a balanced ecosystem.

## 🚀 Features
- **Caps on Fees**: Buy and sell taxes are capped at 10% to prevent excessive fees.
- **Community Governance**: Fee adjustments and blacklisting decisions are subject to community votes.
- **Slippage Protection**: Built-in slippage tolerance for token swapping and liquidity management.
- **Vesting Mechanism**: Tokens are released according to a linear vesting schedule.
- **Anti-Whale Measures**: Limits on maximum wallet size and transaction size to prevent price manipulation.
- **Gas Optimization**: Efficient contract functions to reduce gas usage during transactions.
- **Gnosis Safe Integration**: Secure ownership management using multisig wallets like Gnosis Safe.

## 🔑 Functions and Modifiers
### Core ERC-20 Functions
- `name()`: Returns the name of the token.
- `symbol()`: Returns the symbol of the token.
- `decimals()`: Returns the number of decimals used by the token.
- `totalSupply()`: Returns the total supply of the token.
- `balanceOf(address account)`: Returns the balance of a given address.
- `transfer(address recipient, uint256 amount)`: Transfers tokens to a recipient.

### Fee Management
- `setBuyTaxes(uint256 liquidityFee, uint256 marketingFee, uint256 teamFee, uint256 donationFee)`: Sets buy taxes, subject to governance approval.
- `setSellTaxes(uint256 liquidityFee, uint256 marketingFee, uint256 teamFee, uint256 donationFee)`: Sets sell taxes, subject to governance approval.

### Governance and Voting
- `startBuyTaxVote()`: Initiates a community vote on new buy taxes.
- `voteBuyTax(bool voteYes)`: Casts a vote on the buy tax proposal.
- `concludeBuyTaxVote()`: Concludes the buy tax voting and applies the new taxes if approved.
- `startBlacklistVote()`: Starts a community vote to blacklist or unblacklist an address.
- `voteBlacklist(bool voteYes)`: Casts a vote on the blacklist proposal.
- `concludeBlacklistVote()`: Concludes the blacklist voting and applies the result if approved.

### Vesting and Token Release
- `setVestingSchedule(address account, uint256 totalAmount, uint256 startTime, uint256 endTime)`: Sets up a vesting schedule for a specific address.
- `releaseVestedTokens()`: Releases the tokens based on the vesting schedule.

### Slippage and Liquidity
- `setSlippageTolerance(uint256 newSlippageTolerance)`: Adjusts the slippage tolerance for liquidity swaps.
- `swapTokensForEth(uint256 tokenAmount)`: Swaps tokens for ETH with slippage protection.
- `addLiquidity(uint256 tokenAmount, uint256 ethAmount)`: Adds liquidity to the Uniswap pool.

## 📜 Contract Security
The contract is built with several layers of security:
- **ReentrancyGuard**: Prevents reentrancy attacks on vulnerable functions.
- **Pausable**: The contract can be paused in case of emergencies.
- **Anti-Bot Mechanism**: Implements a cooldown period between transactions to avoid bot spamming.
- **Gas Price Limit**: Ensures that no transactions occur with excessively high gas prices.

## 🔒 Ownership and Control
Ownership of the contract can be transferred to a **Gnosis Safe multisig wallet** to enhance security. Critical functions, including tax updates and blacklisting, are subject to timelock mechanisms to prevent immediate changes.

## 💻 Code Structure
The code is structured into the following key parts:

- `ERC-20 Core Functions`: Basic token operations such as transfers and approvals.
- `Tax and Fee Management`: Logic for handling buy and sell taxes.
- `Community Voting`: Mechanisms for fee and blacklist voting.
- `Vesting and Token Locking`: Methods for releasing tokens over time.
- `Liquidity and Slippage Management`: Functions for handling liquidity provision and swapping with slippage control.

## 📈 Tokenomics
- **Total Supply**: 1 trillion PPOT tokens.
- **Max Transaction Size**: 1% of the total supply.
- **Max Wallet Size**: 2% of the total supply.
- **Buy Tax**: Configurable up to a 10% cap.
- **Sell Tax**: Configurable up to a 10% cap.

## 💡 How to Use
1. Clone the repository:
   ```bash
   git clone https://github.com/tachneo/PrizePotToken.git

🧑‍💻 Contributing
We welcome contributions to enhance the PrizePot token contract! Please submit a pull request with a clear description of the changes.

contact on prizepot@outlook.com | https://x.com/prize_pot
