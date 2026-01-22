// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseGeneralConfig } from "@fdk/BaseGeneralConfig.sol";
import { Contract } from "./utils/Contract.sol";
import { Network } from "./utils/Network.sol";

contract GeneralConfig is BaseGeneralConfig {
  constructor(string memory artifactPath, string memory deploymentPath) BaseGeneralConfig(artifactPath, deploymentPath) { }

  function _setUpNetworks() internal virtual override {
    setNetworkInfo(Network.Sepolia.data());
    setNetworkInfo(Network.EthMainnet.data());
    setNetworkInfo(Network.RoninDevnet.data());
  }

  function _setUpContracts() internal virtual override {
    _mapContractName(Contract.Counter);
  }

  function _mapContractName(Contract contractEnum) internal {
    _contractNameMap[contractEnum.key()] = contractEnum.name();
  }
}
