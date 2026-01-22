// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20Spendable is IERC20 {
  /**
   * @notice Spend `amount` tokens from `tokenOwner` to `recipient`.
   * @param tokenOwner The address of the token owner.
   * @param amount The amount of tokens to spend.
   * @param recipient The address to receive the paired tokens.
   */
  function spendTokens(address tokenOwner, uint256 amount, address recipient) external;

  /// @notice Return the WRON token.
  function WRON() external view returns (IERC20);
}
