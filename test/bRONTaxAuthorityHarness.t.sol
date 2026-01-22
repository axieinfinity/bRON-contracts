// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { bRONTaxAuthority } from "../src/bRONTaxAuthority.sol";

contract bRONTaxAuthorityHarness is bRONTaxAuthority {
  constructor(address bRON) bRONTaxAuthority(bRON) { }

  function buildTypedDataHash(
    AxieScoreRanked memory axieScoreRanked,
    uint256 sellAmount,
    uint256 expiration,
    uint256 userNonce,
    uint256 masterNonce
  ) public view returns (bytes32) {
    return ECDSA.toTypedDataHash(
      _domainSeparatorV4(), _buildTaxOracleTypeHash(axieScoreRanked, sellAmount, expiration, userNonce, masterNonce)
    );
  }
}
