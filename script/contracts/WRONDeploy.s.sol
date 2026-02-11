// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { DefaultContract } from "@fdk/utils/DefaultContract.sol";
import { Migration } from "../Migration.s.sol";
import { WRONFactory, IWRON } from "@contract-libs/factory/WRONFactory.sol";

contract WRONDeploy is Migration {
  function run() public virtual returns (IWRON wron) {
    wron = WRONFactory.createWRON();

    config.setAddress(config.getCurrentNetwork(), DefaultContract.WRON.key(), address(wron));
  }
}
