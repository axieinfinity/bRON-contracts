// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Vm, VmSafe } from "forge-std/Vm.sol";
import { StdStyle } from "forge-std/StdStyle.sol";
import { console2 as console } from "forge-std/console2.sol";
import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { LibSharedAddress } from "@fdk/libraries/LibSharedAddress.sol";
import { Script } from "forge-std/Script.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

contract BasePostChecker is Script, StdAssertions, StdCheats {
  ISharedArgument public constant config = ISharedArgument(address(LibSharedAddress.CONFIG));

  using StdStyle for *;

  modifier onPostCheck(string memory postCheckLabel) {
    uint256 snapshotId = _beforePostCheck(postCheckLabel);
    _;
    _afterPostCheck(postCheckLabel, snapshotId);
  }

  function _beforePostCheck(string memory postCheckLabel) private returns (uint256 snapshotId) {
    snapshotId = vm.snapshot();
    console.log("\n> ".cyan(), postCheckLabel.blue().italic(), "...");
  }

  function _afterPostCheck(string memory postCheckLabel, uint256 snapshotId) private {
    console.log(string.concat("Postcheck ", postCheckLabel.italic(), " successful!\n").green());
    bool reverted = vm.revertTo(snapshotId);
    assertTrue(reverted, string.concat("Cannot revert to snapshot id: ", vm.toString(snapshotId)));
  }
}
