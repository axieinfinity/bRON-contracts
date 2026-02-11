// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Contract } from "../utils/Contract.sol";
import { bRONTaxAuthority as bRONTaxAuthorityContract } from "../../src/bRONTaxAuthority.sol";
import { BasePostChecker } from "./BasePostChecker.s.sol";

contract PostCheck_bRONTaxAuthority is BasePostChecker {
  ISharedArgument.bRONTaxAuthorityParameter public param;
  bRONTaxAuthorityContract public bRONTaxAuthority;

  function run() external {
    param = config.sharedArguments().bRONTaxAuthority;
    bRONTaxAuthority =
      bRONTaxAuthorityContract(address(config.getAddressFromCurrentNetwork(Contract.bRONTaxAuthority.key())));
    _postCheck__Initializable();
  }

  function _postCheck__Initializable() internal onPostCheck("bRONTaxAuthority_Initializable") {
    assertEq(
      address(bRONTaxAuthority.bRON()),
      address(config.getAddressFromCurrentNetwork(Contract.bRON.key())),
      "Mismatch bRON address"
    );
    assertEq(bRONTaxAuthority.hasRole(0x0, param.admin), true, "Mismatch admin role");
    assertEq(bRONTaxAuthority.hasRole(bRONTaxAuthority.OPERATOR_ROLE(), param.operator), true, "Mismatch operator role");
    assertEq(bRONTaxAuthority.BPS(), 10000, "Mismatch BPS");
    uint256 numRanks = bRONTaxAuthority.getNumberOfRanks();
    assertEq(numRanks, param.taxBPSArray.length, "Mismatch number of ranks");
    for (uint256 i = 0; i < numRanks; i++) {
      assertEq(
        uint256(bRONTaxAuthority.getTaxBPSPerRanked(uint8(i))),
        uint256(param.taxBPSArray[i]),
        "Mismatch tax BPS per ranked"
      );
    }
  }
}
