// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseMigration } from "@fdk/BaseMigration.s.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { ISharedArgument } from "./interfaces/ISharedArgument.sol";
import { Network } from "./utils/Network.sol";
import { PostCheck_bRON } from "./post-checker/PostCheck_bRON.s.sol";
import { PostCheck_bRONTaxAuthority } from "./post-checker/PostCheck_bRONTaxAuthority.s.sol";

contract Migration is BaseMigration {
  ISharedArgument public constant config = ISharedArgument(address(CONFIG));

  function _configByteCode() internal virtual override returns (bytes memory) {
    return abi.encodePacked(vm.getCode("out/GeneralConfig.sol/GeneralConfig.json"), abi.encode("", "deployments/"));
  }

  function _sharedArguments() internal virtual override returns (bytes memory rawArgs) {
    ISharedArgument.SharedParameter memory param;

    if (network() == Network.Sepolia.key()) {
      // Undefined
    } else if (network() == DefaultNetwork.RoninMainnet.key()) {
      address admin = 0x9D05D1F5b0424F8fDE534BC196FFB6Dd211D902a;

      param.bRONTaxAuthority.admin = admin;
      // this is unlikely to be changed so we let admin be the operator to be safe
      param.bRONTaxAuthority.operator = admin;
      param.bRONTaxAuthority.taxBPSArray = new uint16[](1);
      param.bRONTaxAuthority.taxBPSArray[0] = 100_00; // 100%

      param.bRON.owner = admin;
      param.bRON.taxTreasury = 0x22cEfc91E9b7c0f3890eBf9527EA89053490694e; // Ronin Treasury

      param.bRONSpenderMock.admin = admin;
      param.bRONSpenderMock.treasury = admin;
    } else if (network() == DefaultNetwork.RoninTestnet.key()) {
      address admin = 0x968D0Cd7343f711216817E617d3f92a23dC91c07; // Testnet admin

      param.bRONTaxAuthority.admin = admin;
      param.bRONTaxAuthority.operator = admin; // need to be replaced
      param.bRONTaxAuthority.taxBPSArray = new uint16[](1);
      param.bRONTaxAuthority.taxBPSArray[0] = 100_00; // 100%
      param.bRON.owner = admin;
      param.bRON.taxTreasury = admin;

      param.bRONSpenderMock.admin = admin;
      param.bRONSpenderMock.treasury = admin;
    } else if (network() == DefaultNetwork.LocalHost.key()) {
      address admin = config.getSender();

      param.bRONTaxAuthority.admin = admin;
      param.bRONTaxAuthority.operator = admin;
      param.bRONTaxAuthority.taxBPSArray = new uint16[](6);
      param.bRONTaxAuthority.taxBPSArray[0] = 80_00; // Lunacian 80%
      param.bRONTaxAuthority.taxBPSArray[1] = 70_00; // Pioneer 70%
      param.bRONTaxAuthority.taxBPSArray[2] = 50_00; // Atia Seeker 50%
      param.bRONTaxAuthority.taxBPSArray[3] = 30_00; // Chosen of Atia 30%
      param.bRONTaxAuthority.taxBPSArray[4] = 15_00; // Atia Guardian 15%
      param.bRONTaxAuthority.taxBPSArray[5] = 5_00; // Myth Keeper 5%

      param.bRON.owner = admin;
      param.bRON.taxTreasury = makeAddr("taxTreasury");

      param.creatorTokenTransferValidatorConfiguration.owner = admin;
      param.creatorTokenTransferValidatorConfiguration.nativeValueToCheckPauseState = 1000 ether;
      param.creatorTokenTransferValidator.owner = admin;
      param.creatorTokenTransferValidator.name = "CreatorTokenTransferValidator";
      param.creatorTokenTransferValidator.version = "5.0.0";

      param.bRONSpenderMock.admin = admin;
      param.bRONSpenderMock.treasury = admin;
    } else {
      revert("Migration: Network Unknown Shared Parameters Unimplemented!");
    }

    rawArgs = abi.encode(param);
  }

  function _postCheck() internal virtual override {
    new PostCheck_bRON().run();
    new PostCheck_bRONTaxAuthority().run();
  }
}
