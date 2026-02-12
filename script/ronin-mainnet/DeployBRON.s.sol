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
    bRONContract bRON = new bRONDeploy().run();
    bRONTaxAuthorityContract bRONTaxAuthority = new bRONTaxAuthorityDeploy().run();

    // initialize bRON
    ISharedArgument.bRONParameter memory bRONParam = config.sharedArguments().bRON;

    // initialize bRONTaxAuthority
    ISharedArgument.bRONTaxAuthorityParameter memory bRONTaxAuthorityParam = config.sharedArguments().bRONTaxAuthority;

    // set up creator token transfer validator
    CreatorTokenTransferValidator creatorTokenTransferValidatorContract =
      CreatorTokenTransferValidator(loadContract(Contract.CreatorTokenTransferValidator.key()));

    address deployer = address(sender());

    vm.startBroadcast(deployer);
    bRON.initialize(deployer, address(bRONTaxAuthority), bRONParam.taxTreasury);
    bRONTaxAuthority.initialize(
      bRONTaxAuthorityParam.admin, bRONTaxAuthorityParam.operator, bRONTaxAuthorityParam.taxBPSArray
    );

    bRON.setTransferValidator(address(creatorTokenTransferValidatorContract));
    uint120 listId = creatorTokenTransferValidatorContract.createListCopy("bRON", 0);
    creatorTokenTransferValidatorContract.applyListToCollection(address(bRON), listId);
    creatorTokenTransferValidatorContract.setTokenTypeOfCollection(address(bRON), 20);
    creatorTokenTransferValidatorContract.setTransferSecurityLevelOfCollection(address(bRON), 4, false, false, false);

    bRON.transferOwnership(bRONParam.owner);
    vm.stopBroadcast();
  }

  function _afterRunningScript() internal virtual override { }
}
