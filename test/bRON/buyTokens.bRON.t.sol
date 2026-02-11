// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { BaseBRONTest } from "../Base.t.sol";
import {
  CreatorTokenTransferValidator
} from "@limitbreak-creator-token-standard-v5-5.0.0/utils/CreatorTokenTransferValidator.sol";
import { IbRON } from "../../src/interfaces/IbRON.sol";

contract BuyTokens_BRON_Test is BaseBRONTest {
  address buyer = makeAddr("buyer");

  function setUp() public override {
    super.setUp();

    vm.prank(buyer);
    WRONContract.approve(address(bRONContract), type(uint256).max);
  }

  function testFuzz_SuccessWhen_BuyToken_ForAnyone(address anyone) public notZeroAddress(anyone) {
    _mintWRON(buyer, 1 ether);

    vm.prank(buyer);
    bRONContract.buyTokens(anyone, 1 ether);

    assertEq(bRONContract.balanceOf(anyone), 1 ether);
    assertEq(bRONContract.balanceOf(buyer), 0);
  }

  function testFuzz_RevertWhen_InsufficientAllowance(address recipient, uint256 amount)
    public
    notZeroAddress(recipient)
  {
    amount = _boundWRONMintAmount(amount);

    _mintWRON(buyer, amount);

    vm.prank(buyer);
    WRONContract.approve(address(bRONContract), amount - 1);

    vm.prank(buyer);
    vm.expectRevert("SafeERC20: low-level call failed");
    bRONContract.buyTokens(recipient, amount);
  }

  function testFuzz_RevertWhen_ZeroBuyAmount(address recipient) public notZeroAddress(recipient) {
    vm.expectRevert(IbRON.ZeroAmount.selector);
    vm.prank(buyer);
    bRONContract.buyTokens(recipient, 0);
  }

  function testFuzz_RevertWhen_OverflowAmount(address recipient) public notZeroAddress(recipient) {
    vm.prank(buyer);
    WRONContract.approve(address(bRONContract), type(uint256).max);

    vm.prank(buyer);
    vm.expectRevert();
    bRONContract.buyTokens(recipient, type(uint256).max);
  }

  function testFuzz_SuccessWhen_EventEmission(address recipient) public notZeroAddress(recipient) {
    _mintWRON(buyer, 1 ether);

    vm.prank(buyer);
    WRONContract.approve(address(bRONContract), 1 ether);

    vm.prank(buyer);
    vm.expectEmit(true, true, false, true);
    emit IbRON.TokenBought(buyer, recipient, 1 ether, 1 ether);
    bRONContract.buyTokens(recipient, 1 ether);
  }

  function testFuzz_SuccessWhen_MultipleBuys(address recipient) public notZeroAddress(recipient) {
    _mintWRON(buyer, 2 ether);

    vm.prank(buyer);
    WRONContract.approve(address(bRONContract), 2 ether);

    // First buy
    vm.prank(buyer);
    bRONContract.buyTokens(recipient, 1 ether);

    // Second buy
    vm.prank(buyer);
    bRONContract.buyTokens(recipient, 1 ether);

    assertEq(bRONContract.balanceOf(recipient), 2 ether);
    assertEq(WRONContract.balanceOf(address(bRONContract)), 2 ether);
  }

  function testFuzz_SuccessWhen_PriceCalculation(address recipient) public notZeroAddress(recipient) {
    uint256 buyAmount = 1000 ether;
    uint256 expectedPairedIn = bRONContract.exposed_calculatePairedIn(buyAmount);

    _mintWRON(buyer, expectedPairedIn);

    vm.prank(buyer);
    WRONContract.approve(address(bRONContract), expectedPairedIn);

    vm.prank(buyer);
    uint256 actualPairedIn = bRONContract.buyTokens(recipient, buyAmount);

    assertEq(actualPairedIn, expectedPairedIn);
    assertEq(bRONContract.balanceOf(recipient), buyAmount);
  }
}
