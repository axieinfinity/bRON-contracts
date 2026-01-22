// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { DefaultContract } from "@fdk/utils/DefaultContract.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";
import { bRON } from "../../src/bRON.sol";

contract bRONDeploy is Migration {
  function run() public virtual returns (bRON) {
    return bRON(_deployProxy(Contract.bRON.key(), arguments(), abi.encode(loadContract(DefaultContract.WRON.key()))));
  }
}
