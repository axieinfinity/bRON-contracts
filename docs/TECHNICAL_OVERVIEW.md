# bRON Technical Documentation

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Architecture](#architecture)
- [Core Contracts](#core-contracts)
- [Technical Flows](#technical-flows)
- [Tax Authority System](#tax-authority-system)
- [Access Control](#access-control)
- [Security Considerations](#security-considerations)
- [Contract Addresses](#contract-addresses)
- [Events](#events)
- [Error Codes](#error-codes)

---

## Overview

bRON (Bonded RON) is an ERC20 token backed 1:1 by WRON (Wrapped RON). The system implements a bonding curve mechanism with tax-based selling and a whitelisted spender system for authorized token spending.

---

## Prerequisites

Before working with bRON contracts, ensure you have the following installed:

- **Git** >= 2.40
- **Node.js** >= 18.x (for Yarn)
- **Yarn** >= 1.22
- **Foundry** (latest version)

---

## Installation

### Step 1: Install Foundry

Foundry is the development framework used for bRON contracts. Install it via `foundryup`:

```bash
# Install foundryup (Foundry toolchain installer)
curl -L https://foundry.paradigm.xyz | bash

# Reload your shell or run
source ~/.bashrc  # or ~/.zshrc for zsh users

# Install/update Foundry
foundryup
```

Verify installation:
```bash
forge --version
cast --version
anvil --version
```

### Step 2: Clone the Repository

```bash
git clone <repository-url>
cd bRON-contracts
```

### Step 3: Install Dependencies

```bash
# Install Node.js dependencies
yarn install

# Install Solidity dependencies via Soldeer
forge soldeer update
```

### Step 4: Build Contracts

```bash
forge build
```

### Step 5: Run Tests

```bash
forge test
```

### Step 6: Format Code

```bash
forge fmt
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        bRON Ecosystem                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌──────────────────┐    ┌───────────────┐  │
│  │    Users    │───▶│      bRON        │◀───│  Tax Treasury │  │
│  └─────────────┘    │   (ERC20 Token)  │    └───────────────┘  │
│        │            └────────┬─────────┘                        │
│        │                     │                                  │
│        ▼                     ▼                                  │
│  ┌─────────────┐    ┌──────────────────┐                       │
│  │    WRON     │◀──▶│  bRONTaxAuthority│                       │
│  │  (Backing)  │    │  (Tax Oracle)    │                       │
│  └─────────────┘    └──────────────────┘                       │
│        ▲                                                        │
│        │            ┌──────────────────┐                       │
│        └────────────│ Whitelisted      │                       │
│                     │ Spenders         │                       │
│                     └──────────────────┘                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## Core Contracts

### 1. bRON.sol

The main ERC20 token contract with bonding mechanism.

**Key Constants:**
- `PAIRED_PRICE_PER_TOKEN_NUMERATOR` = 1,000,000 (1:1 ratio)
- `PAIRED_PRICE_PER_TOKEN_DENOMINATOR` = 1,000,000
- `BPS` = 10,000 (100% in basis points)

**Key Features:**
- ERC20C compatible (Creator Token Standard)
- Pausable by owner
- Reentrancy protected
- Ownable2Step for secure ownership transfer

### 2. bRONTaxAuthority.sol

Determines sell tax rates based on user rankings via operator-signed messages.

**Key Features:**
- EIP-712 typed signatures
- Dual-nonce system for replay protection
- Up to 15 tax tiers (ranks 0-14)
- Role-based access control (Admin, Operator)

### 3. bRONSpenderUpgradeable.sol

Abstract contract for building whitelisted spender integrations.

---

## Technical Flows

### Flow 1: Buying bRON (Minting)

```
User                    bRON Contract              WRON
  │                          │                       │
  │  1. approve(bRON, amount)│                       │
  │  ─────────────────────────────────────────────▶ │
  │                          │                       │
  │  2. buyTokens(recipient, │                       │
  │     buyAmount)           │                       │
  │  ──────────────────────▶ │                       │
  │                          │                       │
  │                          │  3. transferFrom      │
  │                          │     (user, bRON,      │
  │                          │      amount)          │
  │                          │  ───────────────────▶ │
  │                          │                       │
  │  4. Mint bRON to         │                       │
  │     recipient            │                       │
  │  ◀────────────────────── │                       │
```

**Code:**
```solidity
// Step 1: Approve WRON spending
WRON.approve(address(bRON), buyAmount);

// Step 2: Buy bRON tokens (1:1 ratio)
uint256 wronSpent = bRON.buyTokens(recipient, buyAmount);
// wronSpent == buyAmount (1:1 ratio)
```

### Flow 2: Selling bRON (Burning with Tax)

```
User                bRON Contract         TaxAuthority      Tax Treasury
  │                      │                      │                 │
  │  1. sellTokens(      │                      │                 │
  │     amount,          │                      │                 │
  │     minOut,          │                      │                 │
  │     extraData)       │                      │                 │
  │  ──────────────────▶ │                      │                 │
  │                      │                      │                 │
  │                      │  2. determineSellTaxBPS               │
  │                      │  ─────────────────▶  │                 │
  │                      │                      │                 │
  │                      │  3. Return taxBPS    │                 │
  │                      │  ◀─────────────────  │                 │
  │                      │                      │                 │
  │  4. Burn bRON        │                      │                 │
  │  ◀────────────────── │                      │                 │
  │                      │                      │                 │
  │  5. Transfer WRON    │                      │                 │
  │     (after tax)      │                      │                 │
  │  ◀────────────────── │                      │                 │
  │                      │                      │                 │
  │                      │  6. Transfer tax to treasury          │
  │                      │  ──────────────────────────────────▶  │
```

**Tax Calculation:**
```
amountOutBeforeTax = sellAmount × (NUMERATOR / DENOMINATOR)
actualPairedOut = amountOutBeforeTax × (BPS - taxBPS) / BPS
taxAmount = sellAmount - actualPairedOut
```

**Code:**
```solidity
// Without signature (maximum tax applied)
bRON.sellTokens(sellAmount, minAmountOut, "");

// With signature (reduced tax based on rank)
bytes memory extraData = abi.encode(
    axieScoreRanked,  // AxieScoreRanked struct
    deadline,          // uint256
    userNonce,         // uint256
    masterNonce,       // uint256
    signature          // bytes
);
bRON.sellTokens(sellAmount, minAmountOut, extraData);
```

### Flow 3: Spending bRON (Whitelisted Spender)

```
User              Spender Contract         bRON Contract           WRON
  │                      │                      │                    │
  │  1. approve(spender, │                      │                    │
  │     amount)          │                      │                    │
  │  ─────────────────────────────────────────▶ │                    │
  │                      │                      │                    │
  │  2. spendAction()    │                      │                    │
  │  ──────────────────▶ │                      │                    │
  │                      │                      │                    │
  │                      │  3. spendTokens(     │                    │
  │                      │     tokenOwner,      │                    │
  │                      │     amount,          │                    │
  │                      │     recipient)       │                    │
  │                      │  ──────────────────▶ │                    │
  │                      │                      │                    │
  │                      │                      │  4. Burn bRON from │
  │                      │                      │     tokenOwner     │
  │                      │                      │                    │
  │                      │                      │  5. Transfer WRON  │
  │                      │                      │     to recipient   │
  │                      │                      │  ─────────────────▶│
```

**Key Points:**
- Burns bRON from token owner
- Transfers equivalent WRON to recipient (1:1, no tax)
- Only whitelisted spenders can call `spendTokens`
- Requires user's prior approval to the bRON contract

---

## Tax Authority System

### Tax Tiers

Tax rates are configured per rank (0-14), stored in a packed uint256:
```
[numRank(16 bits) | taxBPS[14] | taxBPS[13] | ... | taxBPS[0]]
```

- Rank 0: Default/fallback tax (highest)
- Higher ranks: Lower tax rates
- Tax must be in descending order: `taxBPS[0] >= taxBPS[1] >= ... >= taxBPS[n]`

### Dual-Nonce System

1. **userNonce**: Per-user replay protection
   - Consumed on each successful sell
   - Prevents same signature reuse by same user

2. **masterNonce**: Batch invalidation
   - NOT consumed on use
   - Allows operator to invalidate all signatures with same masterNonce

### Signature Structure (EIP-712)

```solidity
struct AxieScoreRanked {
    address user;     // Seller address
    uint8 rank;       // User's rank (0-14)
    uint256 axieScore; // User's axie score
}

// Typed data for signing
TaxOracleTypeHash(
    AxieScoreRanked axieScoreRanked,
    uint256 sellAmount,
    uint256 deadline,
    uint256 userNonce,
    uint256 masterNonce
)
```

---

## Access Control

### bRON Contract
| Role | Permissions |
|------|-------------|
| Owner | Pause/unpause, set tax authority, set tax treasury, whitelist spenders, withdraw shares |

### bRONTaxAuthority Contract
| Role | Permissions |
|------|-------------|
| DEFAULT_ADMIN_ROLE | Set tax BPS per rank, grant/revoke roles |
| OPERATOR_ROLE | Sign tax signatures, invalidate nonces |

---

## Security Considerations

1. **Reentrancy Protection**: `sellTokens` uses `nonReentrant` modifier
2. **Pausable**: Owner can pause all operations in emergency
3. **Slippage Protection**: `minAmountOut` parameter in `sellTokens`
4. **Signature Expiry**: Deadline check prevents stale signatures
5. **WRON Backing**: Contract ensures `wronLocked >= bRONSupply`

---

## Contract Addresses

*To be filled after deployment*

| Contract | Testnet | Mainnet |
|----------|---------|---------|
| bRON | - | - |
| bRONTaxAuthority | - | - |
| WRON | - | - |

---

## Events

### bRON Events
- `TokenBought(buyer, recipient, amountIn, amountOut)`
- `TokenSold(seller, recipient, amountIn, amountOut)`
- `TokenSpent(spender, tokenOwner, recipient, amount)`
- `SpenderWhitelisted(spender, isWhitelisted)`
- `TaxAuthoritySet(taxAuthority)`
- `TaxTreasurySet(taxTreasury)`
- `SharesWithdrawn(recipient, amount)`

### bRONTaxAuthority Events
- `TaxBPSPerRankedUpdated(rank, taxBPS)`

---

## Error Codes

### bRON Errors
| Error | Description |
|-------|-------------|
| `ZeroAmount()` | Amount cannot be zero |
| `ZeroAddress()` | Address cannot be zero |
| `NotWhitelistedSpender(spender)` | Caller is not whitelisted |
| `SpendToSelf()` | Cannot spend to token owner |
| `CompromisedSlippageProtection()` | Output less than minAmountOut |
| `InsufficientShares()` | Not enough creator shares |
| `InvalidBPS(bps, maxBPS)` | Invalid basis points |
| `InsufficientWRONLocked()` | WRON backing insufficient |

### bRONTaxAuthority Errors
| Error | Description |
|-------|-------------|
| `OnlyBRONCaller()` | Only bRON can call |
| `InvalidSignature()` | Signer not operator |
| `InvalidSellerAddress()` | Seller mismatch |
| `SignatureExpired()` | Past deadline |
| `UsedNonce(sig, user, nonce)` | Nonce already used |
| `InvalidRank(rank, maxRank)` | Rank out of bounds |
