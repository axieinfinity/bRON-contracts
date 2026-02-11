// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";
import { EOARegistry } from "@limitbreak-creator-token-standard-v5-5.0.0/utils/EOARegistry.sol";

contract EOARegistryDeploy is Migration {
  function run() public virtual returns (EOARegistry) {
    return EOARegistry(_deployImmutable(Contract.EOARegistry.key()));
  }
}
