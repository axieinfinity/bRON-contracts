// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TokenFactory } from "@contract-libs/factory/TokenFactory.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import {
  CreatorTokenTransferValidator
} from "@limitbreak-creator-token-standard-v5-5.0.0/utils/CreatorTokenTransferValidator.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { DefaultContract } from "@fdk/utils/DefaultContract.sol";
import { Contract } from "../utils/Contract.sol";
import { Migration } from "../Migration.s.sol";
import { bRONDeploy } from "../contracts/bRONDeploy.s.sol";
import { bRONTaxAuthorityDeploy } from "../contracts/bRONTaxAuthorityDeploy.s.sol";
import { IbRON } from "../../src/interfaces/IbRON.sol";
import { bRON as bRONContract } from "../../src/bRON.sol";
import { bRONTaxAuthority as bRONTaxAuthorityContract } from "../../src/bRONTaxAuthority.sol";

contract bRONDeploy_Mainnet is Migration {
  function _injectDependencies() internal virtual override { }

  function run() public onlyOn(DefaultNetwork.RoninMainnet.key()) {
    // deploy bRON and bRONTaxAuthority
    bRONContract bRONContract = new bRONDeploy().run();
    bRONTaxAuthorityContract bRONTaxAuthorityContract = new bRONTaxAuthorityDeploy().run();

    ISharedArgument.bRONParameter memory bRONParam = config.sharedArguments().bRON;

    // set up transfer validator
    vm.startBroadcast(sender());
    bRONContract.setTaxAuthority(address(bRONTaxAuthorityContract));
    bRONContract.transferOwnership(bRONParam.owner);
    vm.stopBroadcast();
  }
}
