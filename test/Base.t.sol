// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { LibSharedAddress } from "@fdk/libraries/LibSharedAddress.sol";
import { DefaultContract } from "@fdk/utils/DefaultContract.sol";
import { ISharedArgument } from "script/interfaces/ISharedArgument.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { CollectionSecurityPolicyV3 } from "@limitbreak-creator-token-standard-v5-5.0.0/utils/TransferPolicy.sol";
import {
  CreatorTokenTransferValidator
} from "@limitbreak-creator-token-standard-v5-5.0.0/utils/CreatorTokenTransferValidator.sol";
import {
  ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { bRONSpenderMockDeploy } from "script/contracts/bRONSpenderMockDeploy.s.sol";
import { Contract } from "script/utils/Contract.sol";
import { BRONDeploy_Local } from "script/localhost/BRONDeploy_Local.s.sol";
import { ISharedArgument } from "script/interfaces/ISharedArgument.sol";
import { IWRON } from "@contract-libs/interfaces/IWRON.sol";
import { bRON } from "../src/bRON.sol";
import { bRONTaxAuthority } from "../src/bRONTaxAuthority.sol";
import { bRONHarness } from "./bRONHarness.t.sol";
import { bRONTaxAuthorityHarness } from "./bRONTaxAuthorityHarness.t.sol";
import { IbRONTaxAuthority } from "../src/interfaces/IbRONTaxAuthority.sol";
import { bRONSpenderMock } from "../src/mocks/bRONSpenderMock.sol";
import { IbRON } from "../src/interfaces/IbRON.sol";
import { IERC20Spendable } from "../src/interfaces/IERC20Spendable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BaseBRONTest is Test {
  ISharedArgument config = ISharedArgument(LibSharedAddress.VME);
  address SENDER_OR_ADMIN;
  address proxyAdmin;
  IWRON public WRONContract;
  bRONHarness public bRONContract;
  bRONTaxAuthorityHarness public bRONTaxAuthorityContract;
  CreatorTokenTransferValidator public creatorTokenTransferValidatorContract;
  bRONSpenderMock public bRONSpenderMockContract;

  ISharedArgument.bRONParameter bRONParam;
  ISharedArgument.bRONTaxAuthorityParameter bRONTaxAuthorityParam;

  Account taxSigner = makeAccount("taxSigner");

  function setUp() public virtual {
    new BRONDeploy_Local().run();
    new bRONSpenderMockDeploy().run();

    WRONContract = IWRON(config.getAddressFromCurrentNetwork(DefaultContract.WRON.key()));
    bRONContract = bRONHarness(config.getAddressFromCurrentNetwork(Contract.bRON.key()));
    bRONTaxAuthorityContract =
      bRONTaxAuthorityHarness(config.getAddressFromCurrentNetwork(Contract.bRONTaxAuthority.key()));
    proxyAdmin = config.getAddressFromCurrentNetwork(DefaultContract.ProxyAdmin.key());
    creatorTokenTransferValidatorContract =
      CreatorTokenTransferValidator(config.getAddressFromCurrentNetwork(Contract.CreatorTokenTransferValidator.key()));
    bRONSpenderMockContract = bRONSpenderMock(config.getAddressFromCurrentNetwork(Contract.bRONSpenderMock.key()));

    SENDER_OR_ADMIN = config.getSender();
    ISharedArgument.SharedParameter memory sharedParam = config.sharedArguments();

    bRONParam = sharedParam.bRON;
    bRONTaxAuthorityParam = sharedParam.bRONTaxAuthority;

    vm.prank(SENDER_OR_ADMIN);
    bRONTaxAuthorityContract.grantRole(keccak256("OPERATOR_ROLE"), taxSigner.addr);

    // upgrade to harness
    vm.startPrank(proxyAdmin);
    ITransparentUpgradeableProxy(address(bRONContract)).upgradeTo(address(new bRONHarness(address(WRONContract))));
    ITransparentUpgradeableProxy(address(bRONTaxAuthorityContract))
      .upgradeTo(address(new bRONTaxAuthorityHarness(address(bRONContract))));
    vm.stopPrank();
  }

  /// @dev Helper to mint WRON by depositing RON
  function _mintWRON(address to, uint256 amount) internal {
    vm.deal(to, amount);
    vm.prank(to);
    WRONContract.deposit{ value: amount }();
  }

  modifier notZeroAddress(address addr) {
    vm.assume(addr != address(0));
    _;
  }

  modifier notProxyAdmin(address sender) {
    vm.assume(sender != proxyAdmin);
    _;
  }

  modifier notZeroAmount(uint256 amount) {
    vm.assume(amount > 0);
    _;
  }

  function test_setUp() public {
    CollectionSecurityPolicyV3 memory policy =
      creatorTokenTransferValidatorContract.getCollectionSecurityPolicy(address(bRONContract));

    assertEq(policy.disableAuthorizationMode, false);
    assertEq(policy.authorizersCannotSetWildcardOperators, false);
    assertEq(policy.transferSecurityLevel, 4);
    assertEq(policy.listId, 1);

    address[] memory authorizers = creatorTokenTransferValidatorContract.getAuthorizerAccounts(policy.listId);
    assertEq(authorizers.length, 0);

    assertEq(creatorTokenTransferValidatorContract.isVerifiedEOA(makeAddr("alice")), false);
  }

  function test_supportInterfaces() public view {
    assertEq(bRONContract.supportsInterface(type(IbRON).interfaceId), true);
    assertEq(bRONContract.supportsInterface(type(IERC20Spendable).interfaceId), true);
    assertEq(bRONContract.supportsInterface(type(IERC20).interfaceId), true);
  }

  function _genSignatureAndExtraData(
    IbRONTaxAuthority.AxieScoreRanked memory axieScoreRanked,
    uint256 sellAmount,
    uint256 deadline,
    uint256 userNonce,
    uint256 masterNonce
  ) internal view returns (bytes memory signature, bytes memory extraData) {
    return _genSignatureAndExtraData(axieScoreRanked, sellAmount, deadline, userNonce, masterNonce, taxSigner.key);
  }

  function _genSignatureAndExtraData(
    IbRONTaxAuthority.AxieScoreRanked memory axieScoreRanked,
    uint256 sellAmount,
    uint256 deadline,
    uint256 userNonce,
    uint256 masterNonce,
    uint256 signerKey
  ) internal view returns (bytes memory signature, bytes memory extraData) {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(
      signerKey,
      bRONTaxAuthorityContract.buildTypedDataHash(axieScoreRanked, sellAmount, deadline, userNonce, masterNonce)
    );
    signature = abi.encodePacked(r, s, v);
    extraData = abi.encode(axieScoreRanked, deadline, userNonce, masterNonce, signature);
  }

  function _boundWRONMintAmount(uint256 amount) internal pure returns (uint256) {
    // WRON has no cap, but we limit for practical test purposes
    return bound(amount, 1, 1_000_000 ether);
  }
}
