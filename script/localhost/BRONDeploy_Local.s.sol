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
    loadContractOrDeploy(DefaultContract.WRON.key());

    // deploy bRON and bRONTaxAuthority
    bRONContract bRONContract = new bRONDeploy().run();
    bRONTaxAuthorityContract bRONTaxAuthorityContract = new bRONTaxAuthorityDeploy().run();

    ISharedArgument.bRONParameter memory bRONParam = config.sharedArguments().bRON;

    // set up transfer validator
    vm.startPrank(sender());
    bRONContract.setTaxAuthority(address(bRONTaxAuthorityContract));
    bRONContract.transferOwnership(bRONParam.owner);
    vm.stopPrank();

    vm.prank(bRONParam.owner);
    bRONContract.acceptOwnership();
  }
}
