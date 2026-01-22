// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LibString } from "@solady/utils/LibString.sol";
import { TNetwork } from "@fdk/types/Types.sol";
import { INetworkConfig } from "@fdk/interfaces/configs/INetworkConfig.sol";

enum Network {
  Sepolia,
  EthMainnet,
  RoninDevnet
}

using { data, key, name, chainId, chainAlias, envLabel, deploymentDir, explorer } for Network global;

function data(Network network) pure returns (INetworkConfig.NetworkData memory) {
  return INetworkConfig.NetworkData({
    network: key(network),
    blockTime: blockTime(network),
    chainId: chainId(network),
    chainAlias: chainAlias(network),
    explorer: explorer(network)
  });
}

function chainId(Network network) pure returns (uint256) {
  if (network == Network.Sepolia) return 11155111;
  if (network == Network.EthMainnet) return 1;
  if (network == Network.RoninDevnet) return 2022;
  revert("Network: Unknown chain id");
}

function key(Network network) pure returns (TNetwork) {
  return TNetwork.wrap(LibString.packOne(name(network)));
}

function explorer(Network network) pure returns (string memory link) {
  if (network == Network.Sepolia) return "https://sepolia.etherscan.io/";
  if (network == Network.EthMainnet) return "https://etherscan.io/";
}

function name(Network network) pure returns (string memory) {
  if (network == Network.Sepolia) return "Sepolia";
  if (network == Network.RoninDevnet) return "RoninDevnet";
  if (network == Network.EthMainnet) return "EthMainnet";
  revert("Network: Unknown network name");
}

function deploymentDir(Network network) pure returns (string memory) {
  if (network == Network.Sepolia) return "sepolia/";
  if (network == Network.EthMainnet) return "ethereum/";
  if (network == Network.RoninDevnet) return "ronin-devnet/";
  revert("Network: Unknown network deployment directory");
}

function envLabel(Network network) pure returns (string memory) {
  if (network == Network.Sepolia) return "TESTNET_PK";
  if (network == Network.RoninDevnet) return "DEVNET_PK";
  if (network == Network.EthMainnet) return "MAINNET_PK";
  revert("Network: Unknown private key env label");
}

function chainAlias(Network network) pure returns (string memory) {
  if (network == Network.Sepolia) return "sepolia";
  if (network == Network.EthMainnet) return "ethereum";
  if (network == Network.RoninDevnet) return "ronin-devnet";
  revert("Network: Unknown network alias");
}

function blockTime(Network network) pure returns (uint256) {
  if (network == Network.Sepolia) return 15;
  if (network == Network.EthMainnet) return 15;
  if (network == Network.RoninDevnet) return 3;
  revert("DefaultNetwork: Unknown block time");
}
