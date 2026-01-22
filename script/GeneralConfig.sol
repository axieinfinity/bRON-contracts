// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseGeneralConfig } from "@fdk/BaseGeneralConfig.sol";
import { DefaultNetwork } from "@fdk/utils/DefaultNetwork.sol";
import { Contract } from "./utils/Contract.sol";
import { Network } from "./utils/Network.sol";

contract GeneralConfig is BaseGeneralConfig {
  constructor(string memory artifactPath, string memory deploymentPath)
    BaseGeneralConfig(artifactPath, deploymentPath)
  { }

  function _setUpNetworks() internal virtual override {
    setNetworkInfo(Network.Sepolia.data());
    setNetworkInfo(Network.EthMainnet.data());
    setNetworkInfo(Network.RoninDevnet.data());
  }

  function _setUpContracts() internal virtual override {
    _mapContractName(Contract.EOARegistry);
    _mapContractName(Contract.CreatorTokenTransferValidator);
    _mapContractName(Contract.bRON);
    _mapContractName(Contract.bRONTaxAuthority);
    _mapContractName(Contract.bRONSpenderMock);

    setContractAbsolutePathMap(
      Contract.CreatorTokenTransferValidatorConfiguration.key(),
      "out/CreatorTokenTransferValidatorConfiguration.sol/CreatorTokenTransferValidatorConfiguration.json"
    );

    // Ronin Testnet
    setAddress(
      DefaultNetwork.RoninTestnet.key(),
      Contract.CreatorTokenTransferValidator.key(),
      0x721C002B0059009a671D00aD1700c9748146cd1B
    );

    // Ronin Mainnet
    setAddress(
      DefaultNetwork.RoninMainnet.key(),
      Contract.CreatorTokenTransferValidator.key(),
      0x721C002B0059009a671D00aD1700c9748146cd1B
    );
  }

  function _mapContractName(Contract contractEnum) internal {
    _contractNameMap[contractEnum.key()] = contractEnum.name();
  }
}
