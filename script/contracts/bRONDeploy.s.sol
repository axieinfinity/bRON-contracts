// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { DefaultContract } from "@fdk/utils/DefaultContract.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";
import { bRON } from "../../src/bRON.sol";

contract bRONDeploy is Migration {
  function _defaultArguments() internal virtual override returns (bytes memory) {
    ISharedArgument.bRONParameter memory bRONParam = config.sharedArguments().bRON;

    return abi.encodeCall(
      bRON.initialize,
      (bRONParam.owner, bRONParam.taxTreasury, loadContract(Contract.CreatorTokenTransferValidator.key()))
    );
  }

  function run() public virtual returns (bRON) {
    return bRON(_deployProxy(Contract.bRON.key(), arguments(), abi.encode(loadContract(DefaultContract.WRON.key()))));
  }
}
