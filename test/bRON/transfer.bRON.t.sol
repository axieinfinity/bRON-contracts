// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { BaseBRONTest } from "../Base.t.sol";
import {
  CreatorTokenTransferValidator
} from "@limitbreak-creator-token-standard-v5-5.0.0/utils/CreatorTokenTransferValidator.sol";
import { IbRON } from "../../src/interfaces/IbRON.sol";

contract Transfer_BRON_Test is BaseBRONTest {
  address holder = makeAddr("holder");

  function setUp() public override {
    super.setUp();

    _mintWRON(holder, 1 ether);

    vm.prank(holder);
    WRONContract.approve(address(bRONContract), type(uint256).max);

    vm.prank(holder);
    bRONContract.buyTokens(holder, 1 ether);
  }

  function test_transfer() public {
    address recipient = makeAddr("recipient");

    vm.expectRevert(CreatorTokenTransferValidator.CreatorTokenTransferValidator__CallerMustBeWhitelisted.selector);
    vm.prank(holder);
    bool success = bRONContract.transfer(recipient, 1 ether);
    assertFalse(success, "Transfer failed");
  }

  function test_transferFrom() public {
    address spender = makeAddr("spender");
    address recipient = makeAddr("recipient");

    vm.prank(holder);
    bRONContract.approve(spender, 1 ether);

    vm.expectRevert(CreatorTokenTransferValidator.CreatorTokenTransferValidator__CallerMustBeWhitelisted.selector);
    vm.prank(spender);
    bool success = bRONContract.transferFrom(holder, recipient, 1 ether);
    assertFalse(success, "TransferFrom failed");
  }
}
