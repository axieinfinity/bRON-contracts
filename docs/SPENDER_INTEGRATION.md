# bRON Spender Integration Guide

This guide explains how to integrate your smart contract as a whitelisted spender for bRON tokens.

## Table of Contents

- [bRON Spender Integration Guide](#bron-spender-integration-guide)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
    - [Step 1: Install Foundry](#step-1-install-foundry)
    - [Step 2: Initialize Your Project](#step-2-initialize-your-project)
    - [Step 3: Install bRON Dependencies](#step-3-install-bron-dependencies)
    - [Step 5: Build Your Project](#step-5-build-your-project)
  - [Quick Start](#quick-start)
    - [Inherit `bRONSpenderUpgradeable`](#inherit-bronspenderupgradeable)
  - [Core Interface](#core-interface)
    - [`IERC20Spendable`](#ierc20spendable)
    - [`IbRONSpender`](#ibronspender)
  - [Integration Steps](#integration-steps)
    - [Step 1: Deploy Your Spender Contract](#step-1-deploy-your-spender-contract)
    - [Step 2: Get Whitelisted](#step-2-get-whitelisted)
    - [Step 3: User Approval Flow](#step-3-user-approval-flow)
  - [Using `bRONSpenderUpgradeable`](#using-bronspenderupgradeable)
    - [`_spendBRON` Function](#_spendbron-function)
    - [`_updateBRON` Function](#_updatebron-function)
  - [Fallback Mechanism](#fallback-mechanism)
  - [Complete Example: Marketplace Contract](#complete-example-marketplace-contract)
  - [User Flow (Frontend Perspective)](#user-flow-frontend-perspective)
    - [1. Check Allowance](#1-check-allowance)
    - [2. Approve Spending](#2-approve-spending)
    - [3. Execute Spend Action](#3-execute-spend-action)
  - [Error Handling](#error-handling)
    - [Common Errors](#common-errors)
    - [Checking Before Spending](#checking-before-spending)
  - [Security Best Practices](#security-best-practices)
  - [Testing](#testing)
  - [Contract Addresses](#contract-addresses)
  - [Support](#support)

---

## Overview

A **Spender** is a whitelisted smart contract that can spend bRON tokens on behalf of users. When tokens are spent:
- bRON is burned from the token owner
- Equivalent WRON is transferred to the recipient (1:1, no tax)

This enables use cases like:
- In-game purchases
- NFT marketplace payments
- Subscription services
- Any service requiring bRON payments

---

## Prerequisites

Before integrating bRON spender, ensure you have:
- **Foundry** (stable version)

---

## Installation

### Step 1: Install Foundry

If you haven't installed Foundry yet, follow these steps:

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

### Step 2: Initialize Your Project

Create a new Foundry project or use an existing one:

```bash
# Create a new project
forge init my-spender-project
cd my-spender-project

# Or use an existing project
cd your-existing-project
```

### Step 3: Install bRON Dependencies

Add bRON contracts as a dependency using Soldeer or git submodules:

**Using Soldeer (Recommended)**

Add to `foundry.toml`:
```toml
[dependencies]
bRON-contracts = { version = "0.1.0-rc", url = "https://github.com/ronin-labs/bRON-contracts/archive/refs/tags/v0.1.0-rc.zip" }
```

Then run:
```bash
forge soldeer update
```

### Step 5: Build Your Project

```bash
forge build
```

---

## Quick Start

### Inherit `bRONSpenderUpgradeable`

The recommended approach is to inherit the provided abstract contract:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { AccessControlEnumerable } from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import { bRONSpenderUpgradeable } from "bRON-contracts/src/shared/bRONSpenderUpgradeable.sol";

contract MySpender is Initializable, AccessControlEnumerable, bRONSpenderUpgradeable {
    address public treasury;

    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address bRON_, address treasury_) public initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _updateBRON(bRON_);
        treasury = treasury_;
    }

    function updateBRON(address bRON_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _updateBRON(bRON_);
    }

    // Example: User pays for a service
    function purchaseItem(uint256 itemId, uint256 price) external {
        // Business logic here...
        
        // Spend user's bRON - burns bRON, sends WRON to treasury
        bool bRONSpent = _spendBRON(
            msg.sender,     // tokenOwner - whose bRON to spend
            price,          // amount
            treasury,       // recipient - who receives WRON
            true            // fallbackToWRON - if true, uses WRON if bRON fails
        );
        
        // Optionally handle the result
        if (bRONSpent) {
            emit PaidWithBRON(msg.sender, itemId, price);
        } else {
            emit PaidWithWRON(msg.sender, itemId, price);
        }
    }
}
```

---

## Core Interface

### `IERC20Spendable`

```solidity
interface IERC20Spendable is IERC20 {
    /**
     * @notice Spend tokens from tokenOwner to recipient
     * @param tokenOwner The address whose bRON will be burned
     * @param amount The amount of bRON to spend
     * @param recipient The address to receive WRON
     */
    function spendTokens(address tokenOwner, uint256 amount, address recipient) external;

    /// @notice Returns the WRON token address
    function WRON() external view returns (IERC20);
}
```

### `IbRONSpender`

```solidity
interface IbRONSpender {
    error ZeroAddress();
    error NotSupportInterface(address account, bytes4 interfaceId);

    event bRONUpdated(address indexed by, address indexed bRON);

    function getBRON() external view returns (address);
}
```

---

## Integration Steps

### Step 1: Deploy Your Spender Contract

Deploy your contract that either:
- Inherits `bRONSpenderUpgradeable`, or
- Directly calls `IERC20Spendable.spendTokens()`

### Step 2: Get Whitelisted

Contact the bRON contract owner to whitelist your spender address:

```solidity
// Owner calls this on bRON contract
bRON.setWhitelistedSpenders(
    [yourSpenderAddress],
    [true]
);
```

You can verify whitelist status:
```solidity
bool isWhitelisted = bRON.isWhitelistedSpender(yourSpenderAddress);
```

### Step 3: User Approval Flow

Before your spender can spend a user's bRON, the user must approve your spending:

```solidity
// User approves YOUR SPENDER CONTRACT (not bRON) to spend their bRON
bRON.approve(spenderContractAddress, amount);
```

**Important**: The approval is to the **bRON contract**, not your spender. The bRON contract checks allowance when `spendTokens` is called.

---

## Using `bRONSpenderUpgradeable`

### `_spendBRON` Function

```solidity
function _spendBRON(
    address tokenOwner,     // Whose bRON to spend
    uint256 amount,         // Amount to spend
    address recipient,      // Who receives WRON
    bool fallbackToWRON     // Fallback behavior
) internal returns (bool bRONSpent);
```

**Parameters:**
| Parameter | Description |
|-----------|-------------|
| `tokenOwner` | Address whose bRON will be burned |
| `amount` | Amount of tokens to spend |
| `recipient` | Address to receive WRON |
| `fallbackToWRON` | If `true`, transfers WRON directly if bRON spend fails |

**Return Value:**
- `true`: bRON was successfully spent (burned bRON → WRON to recipient)
- `false`: Fallback used (direct WRON transfer from tokenOwner to recipient)

### `_updateBRON` Function

```solidity
function _updateBRON(address bRON) internal;
```

Updates the bRON contract address. Validates:
- Address is not zero
- Contract supports `IERC20Spendable` interface

---

## Fallback Mechanism

The `fallbackToWRON` parameter enables graceful degradation:

```solidity
// With fallback enabled
bool bRONSpent = _spendBRON(user, amount, treasury, true);

if (!bRONSpent) {
    // bRON spend failed, but WRON was transferred instead
    // This happens if:
    // - User doesn't have enough bRON
    // - bRON contract is paused
    // - Spender was removed from whitelist
}
```

**Without fallback:**
```solidity
// Without fallback - reverts on failure
_spendBRON(user, amount, treasury, false);
// If bRON spend fails, transaction reverts
```

**Requirements for fallback:**
- User must have approved WRON spending to your spender contract
- User must have sufficient WRON balance

---

## Complete Example: Marketplace Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { AccessControlEnumerable } from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { bRONSpenderUpgradeable } from "bRON-contracts/src/shared/bRONSpenderUpgradeable.sol";
import { IERC20Spendable } from "bRON-contracts/src/interfaces/IERC20Spendable.sol";

contract NFTMarketplace is Initializable, AccessControlEnumerable, bRONSpenderUpgradeable {
    using SafeERC20 for IERC20;

    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }

    mapping(address => mapping(uint256 => Listing)) public listings;

    event Listed(address indexed nft, uint256 indexed tokenId, address seller, uint256 price);
    event Sold(address indexed nft, uint256 indexed tokenId, address buyer, address seller, uint256 price, bool paidWithBRON);

    function initialize(address admin, address bRON_) public initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _updateBRON(bRON_);
    }

    function listNFT(address nft, uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be > 0");
        IERC721(nft).transferFrom(msg.sender, address(this), tokenId);
        
        listings[nft][tokenId] = Listing({
            seller: msg.sender,
            price: price,
            active: true
        });

        emit Listed(nft, tokenId, msg.sender, price);
    }

    function buyNFT(address nft, uint256 tokenId, bool preferBRON) external {
        Listing storage listing = listings[nft][tokenId];
        require(listing.active, "Not listed");

        address seller = listing.seller;
        uint256 price = listing.price;

        // Mark as sold
        listing.active = false;

        bool paidWithBRON = false;
        
        if (preferBRON) {
            // Try to spend bRON, fallback to WRON
            paidWithBRON = _spendBRON(msg.sender, price, seller, true);
        } else {
            // Direct WRON payment
            IERC20 wron = IERC20Spendable(getBRON()).WRON();
            wron.safeTransferFrom(msg.sender, seller, price);
        }

        // Transfer NFT to buyer
        IERC721(nft).transferFrom(address(this), msg.sender, tokenId);

        emit Sold(nft, tokenId, msg.sender, seller, price, paidWithBRON);
    }
}
```

---

## User Flow (Frontend Perspective)

### 1. Check Allowance

```typescript
const allowance = await bRON.allowance(userAddress, spenderAddress);
if (allowance < requiredAmount) {
    // User needs to approve
}
```

### 2. Approve Spending

```typescript
// Approve the spender contract to spend user's bRON
const tx = await bRON.approve(spenderAddress, amount);
await tx.wait();
```

### 3. Execute Spend Action

```typescript
// Call your spender contract
const tx = await spenderContract.purchaseItem(itemId, price);
await tx.wait();
```

---

## Error Handling

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `NotWhitelistedSpender(spender)` | Spender not whitelisted | Contact bRON owner for whitelisting |
| `SpendToSelf()` | Recipient == tokenOwner | Use different recipient address |
| `ZeroAmount()` | Amount is 0 | Use amount > 0 |
| `ERC20InsufficientAllowance` | User hasn't approved | User must call `bRON.approve()` |
| `ERC20InsufficientBalance` | User lacks bRON | Check balance before spending |

### Checking Before Spending

```solidity
function canSpend(address user, uint256 amount) public view returns (bool) {
    address bRON_ = getBRON();
    
    // Check whitelist
    if (!IbRON(bRON_).isWhitelistedSpender(address(this))) {
        return false;
    }
    
    // Check balance
    if (IERC20(bRON_).balanceOf(user) < amount) {
        return false;
    }
    
    // Check allowance
    if (IERC20(bRON_).allowance(user, address(this)) < amount) {
        return false;
    }
    
    return true;
}
```

---

## Security Best Practices

1. **Validate inputs**: Always check amounts and addresses
2. **Access control**: Use role-based access for admin functions
3. **Reentrancy**: Use `nonReentrant` if handling external calls
4. **Allowance checks**: Verify allowance before spending
5. **Event logging**: Emit events for all state changes
6. **Upgradability**: Consider proxy pattern for upgradeable contracts

---

## Testing

```solidity
// Test setup
function setUp() public {
    // Deploy WRON mock
    wron = new MockWRON();
    
    // Deploy bRON
    bron = new bRON(address(wron));
    bron.initialize(owner, taxAuthority, taxTreasury);
    
    // Deploy your spender
    spender = new MySpender();
    spender.initialize(admin, address(bron), treasury);
    
    // Whitelist spender
    vm.prank(owner);
    bron.setWhitelistedSpenders(
        toArray(address(spender)),
        toArray(true)
    );
    
    // User gets bRON
    vm.startPrank(user);
    wron.approve(address(bron), 1000 ether);
    bron.buyTokens(user, 1000 ether);
    
    // User approves spender
    bron.approve(address(spender), 1000 ether);
    vm.stopPrank();
}

function testSpendBRON() public {
    uint256 amount = 100 ether;
    uint256 treasuryBalanceBefore = wron.balanceOf(treasury);
    
    vm.prank(user);
    spender.purchaseItem(1, amount);
    
    // bRON burned
    assertEq(bron.balanceOf(user), 900 ether);
    
    // WRON transferred to treasury
    assertEq(wron.balanceOf(treasury), treasuryBalanceBefore + amount);
}
```

---

## Contract Addresses

| Contract | Testnet | Mainnet |
|----------|---------|---------|
| bRON | TBD | TBD |
| WRON | TBD | TBD |

---

## Support

For whitelisting requests or technical questions, contact the bRON team.
