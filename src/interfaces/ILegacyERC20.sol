// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILegacyERC20 is IERC20 {
  function admin() external view returns (address);
  function changeAdmin(address newAdmin) external;
  function addMinters(address[] memory) external;
  function mint(address to, uint256 amount) external;
}
