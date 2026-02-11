// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { Migration } from "../Migration.s.sol";
import { Contract } from "../utils/Contract.sol";
import { EOARegistryDeploy } from "../contracts/EOARegistryDeploy.s.sol";
import { CreatorTokenTransferValidatorConfigurationDeploy } from
  "../contracts/CreatorTokenTransferValidatorConfigurationDeploy.s.sol";
import { CreatorTokenTransferValidatorDeploy } from "../contracts/CreatorTokenTransferValidatorDeploy.s.sol";

contract TransferValidatorDeploy_Local is Migration {
  address constant DEFAULT_TRANSFER_VALIDATOR = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;

  function run() public onlyOn(DefaultNetwork.LocalHost.key()) {
    new EOARegistryDeploy().run();
    new CreatorTokenTransferValidatorConfigurationDeploy().run();

    address transferValidator = address(new CreatorTokenTransferValidatorDeploy().run());
    vm.etch(DEFAULT_TRANSFER_VALIDATOR, transferValidator.code);
    config.setAddress(
      config.getCurrentNetwork(), Contract.CreatorTokenTransferValidator.key(), DEFAULT_TRANSFER_VALIDATOR
    );
  }
}
