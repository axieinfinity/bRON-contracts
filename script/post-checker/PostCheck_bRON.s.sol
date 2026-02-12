// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Contract } from "../utils/Contract.sol";
import { DefaultContract } from "@fdk/utils/DefaultContract.sol";
import { bRON as bRONContract } from "../../src/bRON.sol";
import { BasePostChecker } from "./BasePostChecker.s.sol";
import { ILegacyERC20 } from "../../src/interfaces/ILegacyERC20.sol";
import {
  ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { LibProxy } from "@fdk/libraries/LibProxy.sol";
import { console2 as console } from "forge-std/console2.sol";

contract PostCheck_bRON is BasePostChecker {
  address alice = makeAddr("alice");
  address bob = makeAddr("bob");
  address charlie = makeAddr("charlie");
  ISharedArgument.bRONParameter public param;
  bRONContract public bRON;
  ILegacyERC20 public WRON;

  function run() external {
    param = config.sharedArguments().bRON;
    bRON = bRONContract(address(config.getAddressFromCurrentNetwork(Contract.bRON.key())));
    WRON = ILegacyERC20(address(config.getAddressFromCurrentNetwork(DefaultContract.WRON.key())));
    _postCheck__ProxyAdmin();
    _postCheck__ImplementationAddress();
    _postCheck__Initializable();
    _postCheck__NonTransferable_OTC();
    _postCheck__NonTransferable_TransferFrom();
    _postCheck__BuyTokens();
    _postCheck__SellTokens();
    _postCheck__SpendTokens();
  }

  function _postCheck__ImplementationAddress() internal onPostCheck("bRON_ImplementationAddress") {
    ITransparentUpgradeableProxy proxy = ITransparentUpgradeableProxy(payable(address(bRON)));
    address proxyAdmin = LibProxy.getProxyAdmin(address(bRON));
    vm.prank(proxyAdmin);
    address implementation = proxy.implementation();

    assertEq(implementation, LibProxy.getProxyImplementation(address(bRON)), "Mismatch implementation address");
  }

  function _postCheck__ProxyAdmin() internal onPostCheck("bRON_ProxyAdmin") {
    ITransparentUpgradeableProxy proxy = ITransparentUpgradeableProxy(payable(address(bRON)));

    address proxyAdmin = LibProxy.getProxyAdmin(address(bRON));
    vm.prank(proxyAdmin);
    address admin = proxy.admin();

    assertEq(admin, proxyAdmin, "Mismatch proxy admin");
    assertEq(
      admin, address(config.getAddressFromCurrentNetwork(DefaultContract.ProxyAdmin.key())), "Mismatch proxy admin"
    );
  }

  function _postCheck__Initializable() internal onPostCheck("bRON_Initializable") {
    assertEq(keccak256(abi.encodePacked(bRON.name())), keccak256(abi.encodePacked("Bonded RON")), "Mismatch name");
    assertEq(keccak256(abi.encodePacked(bRON.symbol())), keccak256(abi.encodePacked("bRON")), "Mismatch symbol");
    assertEq(bRON.decimals(), 18, "Mismatch decimals");
    assertEq(address(bRON.WRON()), address(WRON), "Mismatch WRON address");
    assertEq(
      address(bRON.getTaxAuthority()),
      address(config.getAddressFromCurrentNetwork(Contract.bRONTaxAuthority.key())),
      "Mismatch tax authority"
    );
    assertEq(address(bRON.getTaxTreasury()), param.taxTreasury, "Mismatch tax treasury");

    address deployer = address(config.getSender());
    address owner = address(bRON.owner());
    address pendingOwner = address(bRON.pendingOwner());
    if (pendingOwner == address(0)) {
      // if there's no pending owner, the owner should be what we defined in the migration
      assertEq(owner, param.owner, "Mismatch owner");
    } else {
      // if there's a pending owner, the pending owner should be the same as the param.owner, and the current owner should be the deployer
      console.log(
        "Warning: bRON owner is currently the deployer. This is expected for the first initialization. Awaiting acceptance of ownership from multisig."
      );
      assertEq(pendingOwner, param.owner, "Mismatch pending owner");
      assertEq(owner, deployer, "Mismatch owner");
    }
  }

  function _postCheck__NonTransferable_OTC() internal onPostCheck("bRON_NonTransferable_OTC") {
    deal(address(bRON), alice, 10 ether, true);

    vm.expectRevert();
    vm.prank(alice);
    bool success = bRON.transfer(bob, 10 ether);
    assertFalse(success, "Transfer should revert");
  }

  function _postCheck__NonTransferable_TransferFrom() internal onPostCheck("bRON_NonTransferable_TransferFrom") {
    deal(address(bRON), alice, 10 ether, true);

    vm.prank(alice);
    bRON.approve(charlie, 10 ether);

    vm.expectRevert();
    vm.prank(charlie);
    bool success = bRON.transferFrom(alice, bob, 10 ether);
    assertFalse(success, "TransferFrom should revert");
  }

  function _postCheck__BuyTokens() internal onPostCheck("bRON_BuyTokens") {
    deal(address(WRON), alice, 10 ether, true);

    vm.prank(alice);
    WRON.approve(address(bRON), 10 ether);

    vm.prank(alice);
    bRON.buyTokens(bob, 1 ether);

    assertEq(bRON.balanceOf(bob), 1 ether);
    assertEq(WRON.balanceOf(address(alice)), 9 ether);
  }

  function _postCheck__SellTokens() internal onPostCheck("bRON_SellTokens") {
    deal(address(WRON), alice, 10 ether, true);

    vm.prank(alice);
    WRON.approve(address(bRON), 10 ether);

    vm.prank(alice);
    bRON.buyTokens(bob, 1 ether);

    vm.prank(bob);
    bRON.sellTokens(1 ether, 0, "");

    assertEq(WRON.balanceOf(address(bob)), 0); // 100% tax has been applied, so receive nothing
    assertEq(bRON.balanceOf(address(bob)), 0); // Bob has sold all his bRON
  }

  function _postCheck__SpendTokens() internal onPostCheck("bRON_SpendTokens") {
    deal(address(WRON), alice, 10 ether, true);

    vm.prank(alice);
    WRON.approve(address(bRON), 10 ether);

    vm.prank(alice);
    bRON.buyTokens(bob, 1 ether);

    vm.prank(bob);
    bRON.approve(charlie, 1 ether);

    address[] memory spenders = new address[](1);
    spenders[0] = charlie;
    bool[] memory isWhitelisted = new bool[](1);
    isWhitelisted[0] = true;

    vm.prank(bRON.owner());
    bRON.setWhitelistedSpenders(spenders, isWhitelisted);

    vm.prank(charlie);
    bRON.spendTokens(bob, 1 ether, charlie);

    assertEq(WRON.balanceOf(charlie), 1 ether);
    assertEq(bRON.balanceOf(bob), 0);
  }
}
