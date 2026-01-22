// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { BaseBRONTest } from "../Base.t.sol";
import { IbRON } from "../../src/interfaces/IbRON.sol";
import { IbRONTaxAuthority } from "../../src/interfaces/IbRONTaxAuthority.sol";
import { UnorderedNonceBitMapUpgradeable } from "@contract-libs/nonce/UnorderedNonceBitMapUpgradeable.sol";

contract SellTokens_BRON_Test is BaseBRONTest {
  address user = makeAddr("user");
  uint256 initialBalance;
  uint256 deadline = block.timestamp + 1000;
  uint256 userNonce = 0;
  uint256 masterNonce = 0;

  uint256 initialBRONSupply;

  function setUp() public override {
    super.setUp();

    initialBalance = 1_000_000 ether;

    _mintWRON(user, initialBalance);

    vm.prank(user);
    WRONContract.approve(address(bRONContract), type(uint256).max);

    vm.prank(user);
    bRONContract.buyTokens(user, initialBalance);

    initialBRONSupply = bRONContract.totalSupply();
  }

  modifier differentFromUser(address recipient) {
    vm.assume(recipient != user);
    _;
  }

  function testFuzz_SuccessWhen_DefaultTax(uint256 sellAmount) public notZeroAmount(sellAmount) {
    sellAmount = bound(sellAmount, 0, initialBalance);

    vm.prank(user);
    uint256 actualPairedOut = bRONContract.sellTokens(sellAmount, 0, "");
    uint256 expectedPairedOut = sellAmount * (10000 - bRONTaxAuthorityContract.getTaxBPSPerRanked(0)) / 10000;

    assertEq(bRONContract.balanceOf(user), initialBalance - sellAmount);
    assertEq(WRONContract.balanceOf(user), expectedPairedOut);
    assertEq(WRONContract.balanceOf(bRONContract.getTaxTreasury()), sellAmount - expectedPairedOut);
    assertEq(actualPairedOut, expectedPairedOut);
    assertEq(bRONContract.totalSupply(), initialBRONSupply - sellAmount);
  }

  function testFuzz_SuccessWhen_WithTax(uint256 sellAmount, uint8 rank) public notZeroAmount(sellAmount) {
    sellAmount = bound(sellAmount, 1, initialBalance);
    rank = uint8(bound(rank, 0, 5));

    (, bytes memory extraData) = _genSignatureAndExtraData(
      IbRONTaxAuthority.AxieScoreRanked({ user: user, rank: rank, axieScore: 100 }),
      sellAmount,
      deadline,
      userNonce,
      masterNonce
    );

    // Sell tokens with tax oracle
    vm.prank(user);
    uint256 actualPairedOut = bRONContract.sellTokens(sellAmount, 0, extraData);
    uint256 expectedPairedOut = sellAmount * (10000 - bRONTaxAuthorityContract.getTaxBPSPerRanked(rank)) / 10000;

    assertEq(bRONContract.balanceOf(user), initialBalance - sellAmount);
    assertEq(WRONContract.balanceOf(user), expectedPairedOut);
    assertEq(WRONContract.balanceOf(bRONContract.getTaxTreasury()), sellAmount - expectedPairedOut);
    assertEq(actualPairedOut, expectedPairedOut);
  }

  function testFuzz_RevertWhen_ZeroSellAmount(uint8 rank) public {
    rank = uint8(bound(rank, 0, 5));
    uint256 zeroSellAmount = 0;

    (, bytes memory extraData) = _genSignatureAndExtraData(
      IbRONTaxAuthority.AxieScoreRanked({ user: user, rank: rank, axieScore: 100 }),
      zeroSellAmount,
      deadline,
      userNonce,
      masterNonce
    );

    // Sell tokens with tax oracle
    vm.prank(user);
    vm.expectRevert(IbRON.ZeroAmount.selector);
    bRONContract.sellTokens(zeroSellAmount, 0, extraData);
  }

  function test_RevertWhen_InsufficientBalance() public {
    uint256 greaterThanOwned = bRONContract.balanceOf(user) + 1;

    // Try to sell more than owned
    vm.prank(user);
    vm.expectRevert("ERC20: burn amount exceeds balance");
    bRONContract.sellTokens(greaterThanOwned, 0, "");
  }

  function testFuzz_RevertWhen_CompromisedSlippageProtection(uint256 sellAmount, uint8 rank)
    public
    notZeroAmount(sellAmount)
  {
    sellAmount = bound(sellAmount, 1, initialBalance);
    rank = uint8(bound(rank, 1, 5));

    (, bytes memory extraData) = _genSignatureAndExtraData(
      IbRONTaxAuthority.AxieScoreRanked({ user: user, rank: rank, axieScore: 100 }),
      sellAmount,
      deadline,
      userNonce,
      masterNonce
    );

    uint256 expectedPairedOut = sellAmount * (10000 - bRONTaxAuthorityContract.getTaxBPSPerRanked(rank)) / 10000;
    uint256 minAmountOut = expectedPairedOut + 1;

    // Try to sell with high minAmountOut
    vm.prank(user);
    vm.expectRevert(IbRON.CompromisedSlippageProtection.selector);
    bRONContract.sellTokens(sellAmount, minAmountOut, extraData);
  }

  function testFuzz_RevertWhen_SignatureInvalid(uint256 sellAmount, uint8 rank) public notZeroAmount(sellAmount) {
    sellAmount = bound(sellAmount, 1, initialBalance);
    rank = uint8(bound(rank, 0, 5));

    // Sign by malicious signer
    Account memory maliciousSigner = makeAccount("malicious-signer");
    (, bytes memory extraData) = _genSignatureAndExtraData(
      IbRONTaxAuthority.AxieScoreRanked({ user: user, rank: rank, axieScore: 100 }),
      sellAmount,
      deadline,
      userNonce,
      masterNonce,
      maliciousSigner.key
    );

    vm.prank(user);
    vm.expectRevert(IbRONTaxAuthority.InvalidSignature.selector);
    bRONContract.sellTokens(sellAmount, 0, extraData);
  }

  function testFuzz_RevertWhen_ExpiredSignature(uint256 sellAmount, uint8 rank) public notZeroAmount(sellAmount) {
    sellAmount = bound(sellAmount, 1, initialBalance);
    rank = uint8(bound(rank, 0, 5));

    deadline = block.timestamp - 1; // Expired

    (, bytes memory extraData) = _genSignatureAndExtraData(
      IbRONTaxAuthority.AxieScoreRanked({ user: user, rank: rank, axieScore: 100 }),
      sellAmount,
      deadline,
      userNonce,
      masterNonce
    );

    vm.prank(user);
    vm.expectRevert(IbRONTaxAuthority.SignatureExpired.selector);
    bRONContract.sellTokens(sellAmount, 0, extraData);
  }

  function testFuzz_RevertWhen_ReplayAttack(uint256 sellAmount, uint8 rank) public notZeroAmount(sellAmount) {
    sellAmount = bound(sellAmount, 1, initialBalance / 2);
    rank = uint8(bound(rank, 0, 5));

    (, bytes memory extraData) = _genSignatureAndExtraData(
      IbRONTaxAuthority.AxieScoreRanked({ user: user, rank: rank, axieScore: 100 }),
      sellAmount,
      deadline,
      userNonce,
      masterNonce
    );

    vm.prank(user);
    bRONContract.sellTokens(sellAmount, 0, extraData);

    vm.prank(user);
    vm.expectRevert(
      abi.encodeWithSelector(
        UnorderedNonceBitMapUpgradeable.UsedNonce.selector,
        IbRONTaxAuthority.determineSellTaxBPS.selector,
        user,
        userNonce
      )
    );
    bRONContract.sellTokens(sellAmount, 0, extraData);
  }

  function testFuzz_RevertWhen_MasterNonceHasBeenInvalidated(uint256 sellAmount, uint8 rank) public {
    sellAmount = bound(sellAmount, 1, initialBalance);
    rank = uint8(bound(rank, 0, 5));

    (, bytes memory extraData) = _genSignatureAndExtraData(
      IbRONTaxAuthority.AxieScoreRanked({ user: user, rank: rank, axieScore: 100 }),
      sellAmount,
      deadline,
      userNonce,
      masterNonce
    );

    // Invalidate the master nonce
    vm.prank(taxSigner.addr);
    bRONTaxAuthorityContract.invalidateUnorderedNonce(taxSigner.addr, masterNonce);

    vm.prank(user);
    vm.expectRevert(
      abi.encodeWithSelector(
        UnorderedNonceBitMapUpgradeable.UsedNonce.selector,
        IbRONTaxAuthority.determineSellTaxBPS.selector,
        taxSigner.addr,
        masterNonce
      )
    );
    bRONContract.sellTokens(sellAmount, 0, extraData);
  }

  function test_SuccessWhen_DifferentTaxRanks(uint256 sellAmount) public notZeroAmount(sellAmount) {
    for (uint8 rank = 0; rank <= 5; rank++) {
      uint256 bRONBalanceOfUserBefore = bRONContract.balanceOf(user);
      uint256 WRONBalanceOfUserBefore = WRONContract.balanceOf(user);
      sellAmount = bound(sellAmount, 1, initialBalance / 6);

      (, bytes memory extraData) = _genSignatureAndExtraData(
        IbRONTaxAuthority.AxieScoreRanked({ user: user, rank: rank, axieScore: 100 }),
        sellAmount,
        deadline,
        userNonce++,
        masterNonce
      );

      vm.prank(user);
      uint256 actualPairedOut = bRONContract.sellTokens(sellAmount, 0, extraData);
      uint256 expectedPairedOut = sellAmount * (10000 - bRONTaxAuthorityContract.getTaxBPSPerRanked(rank)) / 10000;

      assertEq(bRONContract.balanceOf(user), bRONBalanceOfUserBefore - sellAmount, "Mismatch bRON balance of user");
      assertEq(WRONContract.balanceOf(user), WRONBalanceOfUserBefore + expectedPairedOut, "Mismatch WRON balance of user");
      assertEq(actualPairedOut, expectedPairedOut, "Mismatch actual paired out");
    }
  }

  function testFuzz_RevertWhen_InvalidExtraDataFormat(uint256 sellAmount) public notZeroAmount(sellAmount) {
    sellAmount = bound(sellAmount, 1, initialBalance);

    // Try with malformed extraData
    bytes memory malformedExtraData = abi.encode("invalid data");

    vm.prank(user);
    vm.expectRevert();
    bRONContract.sellTokens(sellAmount, 0, malformedExtraData);
  }

  function test_SuccessWhen_MultipleSells() public {
    // Multiple sells
    vm.prank(user);
    bRONContract.sellTokens(0.2 ether, 0, "");

    vm.prank(user);
    bRONContract.sellTokens(0.3 ether, 0, "");

    vm.prank(user);
    bRONContract.sellTokens(0.4 ether, 0, "");

    assertEq(bRONContract.balanceOf(user), initialBalance - 0.9 ether);
    assertEq(WRONContract.balanceOf(user), 0.18 ether); // 80% tax has been applied, so 20% left
  }

  function test_SuccessWhen_ZeroTax(uint256 sellAmount, uint8 rank) public notZeroAmount(sellAmount) {
    sellAmount = bound(sellAmount, 1, initialBalance);

    uint16[] memory taxBPSArray = bRONTaxAuthorityContract.getAllTaxBPSPerRanked();
    rank = uint8(bound(rank, 1, taxBPSArray.length - 1));
    taxBPSArray[rank] = 0;

    vm.prank(SENDER_OR_ADMIN);
    bRONTaxAuthorityContract.setTaxBPSPerRanked(taxBPSArray);

    (, bytes memory extraData) = _genSignatureAndExtraData(
      IbRONTaxAuthority.AxieScoreRanked({ user: user, rank: rank, axieScore: 100 }),
      sellAmount,
      deadline,
      userNonce,
      masterNonce
    );

    vm.prank(user);
    uint256 actualPairedOut = bRONContract.sellTokens(sellAmount, 0, extraData);

    assertEq(bRONContract.balanceOf(user), initialBalance - sellAmount);
    assertEq(WRONContract.balanceOf(user), sellAmount);
    assertEq(actualPairedOut, sellAmount);
    assertEq(WRONContract.balanceOf(bRONContract.getTaxTreasury()), 0);
  }

  function test_SuccessWhen_MaximumTax(uint256 sellAmount) public notZeroAmount(sellAmount) {
    sellAmount = bound(sellAmount, 1, initialBalance);
    uint16[] memory taxBPSArray = bRONTaxAuthorityContract.getAllTaxBPSPerRanked();
    taxBPSArray[0] = 10000;

    // Set the tax BPS to 100%
    vm.prank(SENDER_OR_ADMIN);
    bRONTaxAuthorityContract.setTaxBPSPerRanked(taxBPSArray);

    // Create signature with high tax rank
    (, bytes memory extraData) = _genSignatureAndExtraData(
      IbRONTaxAuthority.AxieScoreRanked({ user: user, rank: 0, axieScore: 100 }),
      sellAmount,
      deadline,
      userNonce,
      masterNonce
    );

    vm.prank(user);
    uint256 actualPairedOut = bRONContract.sellTokens(sellAmount, 0, extraData);

    assertEq(bRONContract.balanceOf(user), initialBalance - sellAmount);
    assertEq(WRONContract.balanceOf(user), 0);
    assertEq(actualPairedOut, 0); // Because the tax BPS is 100%, so the paired out amount is 0
  }
}
