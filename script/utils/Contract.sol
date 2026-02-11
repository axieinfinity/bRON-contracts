// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { LibString } from "@solady/utils/LibString.sol";
import { TContract } from "@fdk/types/Types.sol";

enum Contract {
  EOARegistry,
  CreatorTokenTransferValidatorConfiguration,
  CreatorTokenTransferValidator,
  bRON,
  bRONTaxAuthority,
  bRONSpenderMock
}

using { key, name } for Contract global;

function key(Contract contractEnum) pure returns (TContract) {
  return TContract.wrap(LibString.packOne(name(contractEnum)));
}

function name(Contract contractEnum) pure returns (string memory) {
  if (contractEnum == Contract.EOARegistry) return "EOARegistry";
  if (contractEnum == Contract.CreatorTokenTransferValidatorConfiguration) return "CTVC"; // Since the name is > 31 bytes, we need to use a shorter name
  if (contractEnum == Contract.CreatorTokenTransferValidator) return "CreatorTokenTransferValidator";
  if (contractEnum == Contract.bRON) return "bRON";
  if (contractEnum == Contract.bRONTaxAuthority) return "bRONTaxAuthority";
  if (contractEnum == Contract.bRONSpenderMock) return "bRONSpenderMock";
  revert("Contract: Unknown contract");
}
