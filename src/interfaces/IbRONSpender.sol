// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

interface IbRONSpender {
  /// @dev Thrown when the bRON address is the zero address.
  error ZeroAddress();
  /// @dev Thrown when the account does not support the interface.
  error NotSupportInterface(address account, bytes4 interfaceId);

  /// @dev Emitted when the bRON address is updated.
  event bRONUpdated(address indexed by, address indexed bRON);

  /// @notice Return the bRON address.
  function getBRON() external view returns (address);
}
