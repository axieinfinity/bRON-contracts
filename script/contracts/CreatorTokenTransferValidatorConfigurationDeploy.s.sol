// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";
import { CreatorTokenTransferValidatorConfiguration } from
  "@limitbreak-creator-token-standard-v5-5.0.0/utils/CreatorTokenTransferValidatorConfiguration.sol";

contract CreatorTokenTransferValidatorConfigurationDeploy is Migration {
  ISharedArgument.CreatorTokenTransferValidatorConfigurationParameter _param;

  function _defaultArguments() internal virtual override returns (bytes memory) {
    _param = config.sharedArguments().creatorTokenTransferValidatorConfiguration;

    return abi.encode(_param.owner);
  }

  function run() public virtual returns (CreatorTokenTransferValidatorConfiguration) {
    CreatorTokenTransferValidatorConfiguration _configuration = CreatorTokenTransferValidatorConfiguration(
      _deployImmutable(Contract.CreatorTokenTransferValidatorConfiguration.key())
    );

    vm.prank(_param.owner);
    _configuration.setNativeValueToCheckPauseState(_param.nativeValueToCheckPauseState);

    return _configuration;
  }
}
