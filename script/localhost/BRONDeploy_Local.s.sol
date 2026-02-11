// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import {
  CreatorTokenTransferValidator
} from "@limitbreak-creator-token-standard-v5-5.0.0/utils/CreatorTokenTransferValidator.sol";
import { DefaultContract } from "@fdk/utils/DefaultContract.sol";
import { Contract } from "../utils/Contract.sol";
import { Migration } from "../Migration.s.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { IWRON } from "@contract-libs/interfaces/IWRON.sol";
import { bRONDeploy } from "../contracts/bRONDeploy.s.sol";
import { bRONTaxAuthorityDeploy } from "../contracts/bRONTaxAuthorityDeploy.s.sol";
import { TransferValidatorDeploy_Local } from "./TransferValidatorDeploy_Local.s.sol";
import { WRONDeploy } from "../contracts/WRONDeploy.s.sol";
import { bRON as bRONContract } from "../../src/bRON.sol";
import { bRONTaxAuthority as bRONTaxAuthorityContract } from "../../src/bRONTaxAuthority.sol";

contract BRONDeploy_Local is Migration {
  function _injectDependencies() internal virtual override {
    _setDependencyDeployScript(DefaultContract.WRON.key(), new WRONDeploy());
  }

  function run() public onlyOn(DefaultNetwork.LocalHost.key()) {
    new TransferValidatorDeploy_Local().run();

    // Deploy or load WRON
    IWRON wron = IWRON(loadContractOrDeploy(DefaultContract.WRON.key()));

    bRONContract bRON = new bRONDeploy().run();
    bRONTaxAuthorityContract bRONTaxAuthority = new bRONTaxAuthorityDeploy().run();

    // initialize bRON
    ISharedArgument.bRONParameter memory bRONParam = config.sharedArguments().bRON;
    bRON.initialize(bRONParam.owner, address(bRONTaxAuthority), bRONParam.taxTreasury);

    // initialize bRONTaxAuthority
    ISharedArgument.bRONTaxAuthorityParameter memory bRONTaxAuthorityParam = config.sharedArguments().bRONTaxAuthority;
    bRONTaxAuthority.initialize(
      bRONTaxAuthorityParam.admin, bRONTaxAuthorityParam.operator, bRONTaxAuthorityParam.taxBPSArray
    );

    CreatorTokenTransferValidator creatorTokenTransferValidatorContract =
      CreatorTokenTransferValidator(loadContract(Contract.CreatorTokenTransferValidator.key()));

    vm.startPrank(sender());
    // set up creator token transfer validator
    uint120 listId = creatorTokenTransferValidatorContract.createListCopy("bRON", 0);
    creatorTokenTransferValidatorContract.applyListToCollection(address(bRON), listId);
    creatorTokenTransferValidatorContract.setTokenTypeOfCollection(address(bRON), 20);
    creatorTokenTransferValidatorContract.setTransferSecurityLevelOfCollection(address(bRON), 4, false, false, false);
    vm.stopPrank();
  }
}
