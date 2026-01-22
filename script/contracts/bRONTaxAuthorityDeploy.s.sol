// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";
import { bRONTaxAuthority } from "../../src/bRONTaxAuthority.sol";

contract bRONTaxAuthorityDeploy is Migration {
  function run() public virtual returns (bRONTaxAuthority) {
    return bRONTaxAuthority(
      _deployProxy(Contract.bRONTaxAuthority.key(), arguments(), abi.encode(loadContract(Contract.bRON.key())))
    );
  }
}
