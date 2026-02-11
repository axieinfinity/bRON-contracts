// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IGeneralConfig } from "@fdk/interfaces/IGeneralConfig.sol";

interface ISharedArgument is IGeneralConfig {
  struct bRONParameter {
    address owner;
    address taxTreasury;
  }

  struct bRONTaxAuthorityParameter {
    address admin;
    address operator;
    uint16[] taxBPSArray;
  }

  struct CreatorTokenTransferValidatorConfigurationParameter {
    address owner;
    uint256 nativeValueToCheckPauseState;
  }

  struct CreatorTokenTransferValidatorParameter {
    address owner;
    string name;
    string version;
  }

  struct bRONSpenderMockParameter {
    address admin;
    address treasury;
  }

  struct SharedParameter {
    bRONParameter bRON;
    bRONTaxAuthorityParameter bRONTaxAuthority;
    CreatorTokenTransferValidatorConfigurationParameter creatorTokenTransferValidatorConfiguration;
    CreatorTokenTransferValidatorParameter creatorTokenTransferValidator;
    bRONSpenderMockParameter bRONSpenderMock;
  }

  function sharedArguments() external view returns (SharedParameter memory param);
}
