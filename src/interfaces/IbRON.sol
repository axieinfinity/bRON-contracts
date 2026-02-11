// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IbRONTaxAuthority } from "./IbRONTaxAuthority.sol";
import { IERC20Spendable } from "./IERC20Spendable.sol";

interface IbRON is IERC20, IERC20Spendable {
  error LengthMismatch();
  error ZeroAmount();
  error SpendToSelf();
  error ZeroAddress();
  error OverflowAmountPairedIn();
  error CompromisedSlippageProtection();
  error NotWhitelistedSpender(address spender);
  error InsufficientShares();
  error InvalidBPS(uint256 bps, uint256 maxBPS);
  error InsufficientWRONLocked();
  error InvalidPairedOut();

  event TokenBought(address indexed buyer, address indexed recipient, uint256 amountIn, uint256 amountOut);
  event TokenSold(address indexed seller, address indexed recipient, uint256 amountIn, uint256 amountOut);
  event TokenSpent(address indexed spender, address indexed tokenOwner, address indexed recipient, uint256 amount);
  event SharesWithdrawn(address indexed recipient, uint256 amount);
  event SpenderWhitelisted(address indexed spender, bool isWhitelisted);
  event TaxAuthoritySet(address indexed taxAuthority);
  event TaxTreasurySet(address indexed taxTreasury);

  /// @notice Return the paired price per token.
  function PAIRED_PRICE_PER_TOKEN_NUMERATOR() external view returns (uint96);

  /// @notice Return the paired price per token.
  function PAIRED_PRICE_PER_TOKEN_DENOMINATOR() external view returns (uint96);

  /// @notice Return the BPS.
  function BPS() external view returns (uint16);

  /**
   * @notice Buy `buyAmount` tokens with `maxAmountIn` paired tokens.
   *
   * @dev The paired token will be taken from `buyer` and the token will be minted to `recipient`.
   * @dev Emits `TokenBought` event.
   *
   * @param recipient Where the token will be minted to.
   * @param buyAmount The amount of tokens to buy.
   * @return actualPairedIn The actual amount of paired tokens spent.
   */
  function buyTokens(address recipient, uint256 buyAmount) external returns (uint256 actualPairedIn);

  /**
   * @notice Sell `sellAmount` tokens for `minAmountOut` paired tokens.
   *
   * @dev The token will be burned from `msg.sender` and the paired token will be transferred to `msg.sender`.
   * @dev We will not support selling to another address since you can just sell to yourself and transfer to them.
   * @dev Ensure the received amount respects the `minAmountOut` parameter.
   * @dev Emits `TokenSold` event.
   *
   * @param sellAmount The amount of tokens to sell.
   * @param minAmountOut The minimum amount of paired tokens to receive.
   * @param extraData Extra data to pass to the tax oracle.
   */
  function sellTokens(uint256 sellAmount, uint256 minAmountOut, bytes calldata extraData)
    external
    returns (uint256 actualPairedOut);

  /**
   * @notice Return the tax authority.
   * @return The tax authority.
   */
  function getTaxAuthority() external view returns (IbRONTaxAuthority);

  /**
   * @notice Return the tax treasury.
   * @return The tax treasury.
   */
  function getTaxTreasury() external view returns (address);

  /**
   * @notice Set the tax authority.
   * @param taxAuthority The address to set.
   * @dev Emits `TaxAuthoritySet` event.
   */
  function setTaxAuthority(address taxAuthority) external;

  /**
   * @notice Set the tax treasury.
   * @param taxTreasury The address to set.
   * @dev Emits `TaxTreasurySet` event.
   */
  function setTaxTreasury(address taxTreasury) external;

  /**
   * @notice Return if the spender is whitelisted.
   * @param spender The address to check.
   * @return If the spender is whitelisted.
   */
  function isWhitelistedSpender(address spender) external view returns (bool);

  /**
   * @notice Set the whitelisted spenders.
   * @param spenders The addresses to set.
   * @param isWhitelisted The whitelisted status.
   */
  function setWhitelistedSpenders(address[] calldata spenders, bool[] calldata isWhitelisted) external;

  /**
   * @notice Withdraw `amount` shares to `recipient`.
   * @param recipient The address to receive the shares.
   * @param amount The amount of shares to withdraw.
   */
  function withdrawOwnerShares(address recipient, uint256 amount) external;

  /**
   * @notice Return the amount of creator shares.
   * @return The amount of creator shares.
   */
  function getCreatorShares() external view returns (uint256);
}
