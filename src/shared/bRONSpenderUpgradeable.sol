// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { LibErrorHandler } from "@contract-libs/LibErrorHandler.sol";
import { IERC20Spendable } from "../interfaces/IERC20Spendable.sol";
import { IbRONSpender } from "../interfaces/IbRONSpender.sol";

abstract contract bRONSpenderUpgradeable is IbRONSpender {
  /// @custom:storage-location ronin.storage.bRONSpenderUpgradeable
  struct BRONSpenderStorage {
    address _bRON;
  }

  // keccak256(abi.encode(uint256(keccak256("ronin.storage.bRONSpender")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant $$__BRONSpenderStorageLocation =
    0x5c8e96d3e8c76bdf4e32c64f00a9a3c8c6d7e0f9a1b2c3d4e5f6071829304a00;

  /// @dev Return the custom slot.
  function _getBRONSpenderStorage() private pure returns (BRONSpenderStorage storage $) {
    assembly ("memory-safe") {
      $.slot := $$__BRONSpenderStorageLocation
    }
  }

  /// @inheritdoc IbRONSpender
  function getBRON() public view returns (address) {
    return _getBRONSpenderStorage()._bRON;
  }

  /**
   * @dev Attempts to spend bRON tokens from the specified token owner to the recipient.
   * If the bRON spend fails, the WRON will be transferred to the recipient.
   *
   * @param tokenOwner The address of bRON owner. Whom bRON will be burned from.
   * @param amount The amount of bRON to spend.
   * @param recipient The address to receive the bRON.
   * @param fallbackToWRON If true, the function will fallback to WRON if the bRON spend fails.
   * @return bRONSpent Whether the bRON was spent successfully. If false, the WRON will be transferred to the recipient.
   */
  function _spendBRON(address tokenOwner, uint256 amount, address recipient, bool fallbackToWRON)
    internal
    returns (bool bRONSpent)
  {
    address bRON = _getBRONSpenderStorage()._bRON;
    (bool success, bytes memory data) =
      bRON.call(abi.encodeCall(IERC20Spendable.spendTokens, (tokenOwner, amount, recipient)));

    if (success) return true;
    if (!fallbackToWRON) LibErrorHandler.handleRevert({ status: false, callSig: msg.sig, returnOrRevertData: data });

    SafeERC20.safeTransferFrom({
      token: IERC20Spendable(bRON).WRON(),
      from: tokenOwner,
      to: recipient,
      value: amount
    });
    return false;
  }

  /**
   * @dev Sets the new bRON address
   * Requirements:
   * - `bRON` cannot be the zero address
   * - `bRON` must support the IERC20Spendable interface
   *
   * Emits `bRONUpdated` event.
   */
  function _updateBRON(address bRON) internal {
    require(bRON != address(0), ZeroAddress());
    require(
      ERC165Checker.supportsInterface(bRON, type(IERC20Spendable).interfaceId),
      NotSupportInterface(bRON, type(IERC20Spendable).interfaceId)
    );

    emit bRONUpdated(msg.sender, bRON);
    _getBRONSpenderStorage()._bRON = bRON;
  }
}
