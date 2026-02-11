// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { DefaultContract } from "@fdk/utils/DefaultContract.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";
import { CreatorTokenTransferValidator } from
  "@limitbreak-creator-token-standard-v5-5.0.0/utils/CreatorTokenTransferValidator.sol";
import { CreatorTokenTransferValidatorConfigurationDeploy } from
  "./CreatorTokenTransferValidatorConfigurationDeploy.s.sol";
import { EOARegistryDeploy } from "./EOARegistryDeploy.s.sol";

contract CreatorTokenTransferValidatorDeploy is Migration {
  function _injectDependencies() internal virtual override {
    _setDependencyDeployScript(
      Contract.CreatorTokenTransferValidatorConfiguration.key(), new CreatorTokenTransferValidatorConfigurationDeploy()
    );
    _setDependencyDeployScript(Contract.EOARegistry.key(), new EOARegistryDeploy());
  }

  function _defaultArguments() internal virtual override returns (bytes memory) {
    ISharedArgument.CreatorTokenTransferValidatorParameter memory param =
      config.sharedArguments().creatorTokenTransferValidator;

    return abi.encode(
      param.owner,
      loadContractOrDeploy(Contract.EOARegistry.key()),
      param.name,
      param.version,
      loadContractOrDeploy(Contract.CreatorTokenTransferValidatorConfiguration.key())
    );
  }

  function run() public virtual returns (CreatorTokenTransferValidator) {
    return CreatorTokenTransferValidator(_deployImmutable(Contract.CreatorTokenTransferValidator.key()));
  }
}
