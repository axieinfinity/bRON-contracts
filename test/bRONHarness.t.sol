// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { bRON } from "../src/bRON.sol";

contract bRONHarness is bRON {
  constructor(address WRON_) bRON(WRON_) { }

  function exposed_calculatePairedIn(uint256 amountOut) public pure returns (uint256) {
    return super._calculatePairedIn(amountOut);
  }

  function exposed_calculatePairedOut(uint256 amountIn, uint256 taxBPS) public pure returns (uint256) {
    return super._calculatePairedOut(amountIn, taxBPS);
  }
}
