// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { BaseBRONTest } from "../Base.t.sol";
import { IbRON } from "../../src/interfaces/IbRON.sol";

contract SpendTokens_BRON_Test is BaseBRONTest {
  address user = makeAddr("user");
  uint256 initialBRONBalance;
  uint256 initialWRONBalance;
  uint256 initialBRONSupply;

  function setUp() public override {
    super.setUp();

    initialBRONBalance = 500_000 ether;
    initialWRONBalance = initialBRONBalance;

    // Mint WRON for both bRON purchase and extra WRON balance
    _mintWRON(user, initialBRONBalance + initialWRONBalance);

    vm.prank(user);
    WRONContract.approve(address(bRONContract), type(uint256).max);

    vm.prank(user);
    bRONContract.buyTokens(user, initialBRONBalance);

    address[] memory spenders = new address[](1);
    spenders[0] = address(bRONSpenderMockContract);
    bool[] memory isWhitelisted = new bool[](1);
    isWhitelisted[0] = true;
    vm.prank(SENDER_OR_ADMIN);
    bRONContract.setWhitelistedSpenders(spenders, isWhitelisted);

    vm.startPrank(user);
    bRONContract.approve(address(bRONSpenderMockContract), type(uint256).max);
    WRONContract.approve(address(bRONSpenderMockContract), type(uint256).max);
    vm.stopPrank();

    initialBRONSupply = bRONContract.totalSupply();
  }

  function testFuzz_SuccessWhen_NoFallbackToWRON_And_SpendBRON(uint256 amount, bool fallbackToWRON) public {
    amount = bound(amount, 1, initialBRONBalance);

    vm.prank(user);
    bRONSpenderMockContract.spendTokens(amount, fallbackToWRON);

    assertEq(bRONContract.balanceOf(user), initialBRONBalance - amount);
    assertEq(bRONContract.totalSupply(), initialBRONSupply - amount);
    assertEq(WRONContract.balanceOf(bRONSpenderMockContract.treasury()), amount);
  }

  function testFuzz_RevertWhen_NoFallbackToWRON_And_SpendBRON_ZeroAmount() public {
    vm.expectRevert(IbRON.ZeroAmount.selector);
    vm.prank(user);
    bRONSpenderMockContract.spendTokens({ amount: 0, fallbackToWRON: false });
  }

  function testFuzz_RevertWhen_NoFallbackToWRON_And_NotWhitelistedSpender(uint256 amount) public {
    amount = bound(amount, 1, initialBRONBalance);

    address[] memory spenders = new address[](1);
    spenders[0] = address(bRONSpenderMockContract);
    bool[] memory isWhitelisted = new bool[](1);
    isWhitelisted[0] = false;
    vm.prank(SENDER_OR_ADMIN);
    bRONContract.setWhitelistedSpenders(spenders, isWhitelisted);

    vm.prank(user);
    vm.expectRevert(abi.encodeWithSelector(IbRON.NotWhitelistedSpender.selector, address(bRONSpenderMockContract)));
    bRONSpenderMockContract.spendTokens(amount, false);
  }

  function testFuzz_RevertWhen_NoFallbackToWRON_And_InsufficientAllowance(uint256 amount) public {
    amount = bound(amount, 1, initialBRONBalance);

    vm.prank(user);
    bRONContract.approve(address(bRONSpenderMockContract), amount - 1);

    vm.prank(user);
    vm.expectRevert("ERC20: insufficient allowance");
    bRONSpenderMockContract.spendTokens(amount, false);
  }

  function testFuzz_RevertWhen_NoFallbackToWRON_And_InsufficientBalance(uint256 amount) public {
    vm.assume(amount > initialBRONBalance);
    vm.prank(user);
    vm.expectRevert("ERC20: burn amount exceeds balance");
    bRONSpenderMockContract.spendTokens(amount, false);
  }

  function testFuzz_SuccessWhen_FallbackToWRON_And_TransferWRON(uint256 amount) public {
    amount = bound(amount, 1, initialWRONBalance);

    vm.prank(user);
    bRONContract.approve(address(bRONSpenderMockContract), 0); // reset the approval so the spending would be forced to use WRON

    vm.prank(user);
    bRONSpenderMockContract.spendTokens(amount, true);

    assertEq(bRONContract.balanceOf(user), initialBRONBalance);
    assertEq(bRONContract.totalSupply(), initialBRONSupply);
    assertEq(WRONContract.balanceOf(user), initialWRONBalance - amount);
    assertEq(WRONContract.balanceOf(bRONSpenderMockContract.treasury()), amount);
  }

  function testFuzz_RevertWhen_FallbackToWRON_And_InsufficientApproval_WRON(uint256 amount) public {
    amount = bound(amount, 1, initialWRONBalance);

    vm.startPrank(user);
    bRONContract.approve(address(bRONSpenderMockContract), 0); // reset the approval so the spending would be forced to use WRON
    WRONContract.approve(address(bRONSpenderMockContract), 0);
    vm.stopPrank();

    vm.prank(user);
    vm.expectRevert("SafeERC20: low-level call failed");
    bRONSpenderMockContract.spendTokens(amount, true);
  }

  function testConcrete_RevertWhen_FallbackToWRON_And_InsufficientBalance_WRON() public {
    uint256 amount = initialWRONBalance + 1;

    vm.startPrank(user);
    bRONContract.approve(address(bRONSpenderMockContract), 0); // reset the approval so the spending would be forced to use WRON
    vm.stopPrank();

    vm.prank(user);
    vm.expectRevert("SafeERC20: low-level call failed");
    bRONSpenderMockContract.spendTokens(amount, true);
  }
}
