// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { AccessControlEnumerable } from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IbRONTaxAuthority } from "./interfaces/IbRONTaxAuthority.sol";
import { UnorderedNonceBitMapUpgradeable } from "@contract-libs/nonce/UnorderedNonceBitMapUpgradeable.sol";

/**
 * @title bRONTaxAuthority
 * @notice Determines sell tax rates for bRON token based on user rankings via operator-signed messages.
 *
 * @dev Nonce Design (Dual-Nonce System):
 *
 * This contract uses two nonces for different purposes:
 *
 * 1. `userNonce` - Per-user replay protection
 *    - Tracked per seller address
 *    - Consumed on each successful sell to prevent signature replay by the same user
 *    - Each signature can only be used once per user
 *
 * 2. `masterNonce` - Batch invalidation mechanism
 *    - Tracked per operator (signer) address
 *    - NOT consumed on use, only checked against invalidation
 *    - Allows operator to issue multiple signatures with the same masterNonce
 *    - Operator can invalidate all signatures sharing a masterNonce by calling
 *      `invalidateUnorderedNonce(operatorAddress, masterNonce)`
 *    - Use case: If operator needs to revoke a batch of issued signatures (e.g., rank
 *      recalculation, security incident), they can invalidate one masterNonce to
 *      invalidate all signatures in that batch
 *
 * Example:
 *   - Operator issues 1000 signatures for different users, all with masterNonce = 42
 *   - If ranks need recalculation, operator calls `invalidateUnorderedNonce(operator, 42)`
 *   - All 1000 signatures become invalid immediately
 *   - Operator issues new signatures with masterNonce = 43
 */
contract bRONTaxAuthority is
  Initializable,
  AccessControlEnumerable,
  EIP712,
  UnorderedNonceBitMapUpgradeable,
  IbRONTaxAuthority
{
  bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
  uint256 public constant override BPS = 100_00; // 100%
  // Since we packed all BPS into a uint256:
  // taxBPSPerRank = [numRank(16 bits) | taxBPS(16 bits)(index 14) | ... | taxBPS(16 bits)(index 0)]
  // The maximum rank index is 14, from 0 to 14. Note that the index 0 is the fallback tax BPS.
  uint256 public constant MAX_RANK_INDEX = 14;
  /// @dev Return the bRON token.
  address public immutable override bRON;

  bytes32 public constant AXIE_SCORE_RANKED_TYPE_HASH =
    keccak256("AxieScoreRanked(address user,uint8 rank,uint256 axieScore)");
  bytes32 public constant TAX_ORACLE_TYPE_HASH = keccak256(
    "TaxOracleTypeHash(AxieScoreRanked axieScoreRanked,uint256 sellAmount,uint256 deadline,uint256 userNonce,uint256 masterNonce)AxieScoreRanked(address user,uint8 rank,uint256 axieScore)"
  );

  uint256[50] private __gap;
  /**
   * @dev Structure: [numRank(16 bits) | taxBPS(16 bits)(index 14) | ... | taxBPS(16 bits)(index 0)]
   * The rankIndex must be in range of [0, MAX_RANK_INDEX].
   */
  uint256 internal _taxBPSPerRanked;

  constructor(address bRON_) EIP712("bRONTaxAuthority", "1") {
    bRON = bRON_;
    _disableInitializers();
  }

  function initialize(address admin, address operator, uint16[] calldata taxBPSArray) public initializer {
    _grantRole(DEFAULT_ADMIN_ROLE, admin);
    _grantRole(OPERATOR_ROLE, operator);
    _setManyTaxBPS(taxBPSArray);
  }

  /// @inheritdoc IbRONTaxAuthority
  function getTaxBPSPerRanked(uint8 rank) public view returns (uint16) {
    return uint16(_taxBPSPerRanked >> (16 * rank));
  }

  /// @inheritdoc IbRONTaxAuthority
  function getNumberOfRanks() public view returns (uint256) {
    return _taxBPSPerRanked >> 240;
  }

  /// @inheritdoc IbRONTaxAuthority
  function getAllTaxBPSPerRanked() public view returns (uint16[] memory taxBPSArray) {
    uint256 numRanks = getNumberOfRanks();
    taxBPSArray = new uint16[](numRanks);

    for (uint256 i; i < numRanks; ++i) {
      taxBPSArray[i] = getTaxBPSPerRanked(uint8(i));
    }
    return taxBPSArray;
  }

  /// @inheritdoc IbRONTaxAuthority
  function setTaxBPSPerRanked(uint16[] calldata taxBPSArray) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _setManyTaxBPS(taxBPSArray);
  }

  /**
   * @inheritdoc IbRONTaxAuthority
   * @dev Can be used to:
   *   1. Invalidate a user's specific userNonce (pass user address)
   *   2. Batch-invalidate all signatures with a specific masterNonce (pass operator address)
   */
  function invalidateUnorderedNonce(address user, uint256 nonce) external onlyRole(OPERATOR_ROLE) {
    _useUnorderedNonce(user, nonce);
  }

  /// @inheritdoc IbRONTaxAuthority
  function determineSellTaxBPS(address seller, uint256 sellAmount, bytes calldata extraData) external returns (uint16) {
    require(_msgSender() == bRON, OnlyBRONCaller());

    uint256 numRanks = getNumberOfRanks();
    require(numRanks > 0, EmptyRankList());
    if (extraData.length == 0) return getTaxBPSPerRanked(0);

    require(sellAmount > 0, SellAmountZero());
    (
      AxieScoreRanked memory axieScoreRanked,
      uint256 deadline,
      uint256 userNonce,
      uint256 masterNonce,
      bytes memory signature
    ) = abi.decode(extraData, (AxieScoreRanked, uint256, uint256, uint256, bytes));

    address signer = ECDSA.recover(
      ECDSA.toTypedDataHash(
        _domainSeparatorV4(), _buildTaxOracleTypeHash(axieScoreRanked, sellAmount, deadline, userNonce, masterNonce)
      ),
      signature
    );

    require(hasRole(OPERATOR_ROLE, signer), InvalidSignature());
    require(axieScoreRanked.user == seller, InvalidSellerAddress());
    require(block.timestamp < deadline, SignatureExpired());
    // masterNonce: checked but not consumed - allows batch invalidation by operator
    require(!isUsedNonce(signer, masterNonce), UsedNonce(msg.sig, signer, masterNonce));
    require(
      axieScoreRanked.rank <= Math.min(MAX_RANK_INDEX, numRanks - 1), InvalidRank(axieScoreRanked.rank, MAX_RANK_INDEX)
    );
    // userNonce: consumed to prevent replay by the same user
    _useUnorderedNonce(seller, userNonce);

    return getTaxBPSPerRanked(axieScoreRanked.rank);
  }

  /**
   * @dev Set many tax BPS per ranked.
   * The taxBPS must be in range of [0, BPS].
   * Only support up to 15 ranks.
   * The taxBPSArray must be in descending order. E.g. [10000, 9000, 8000, ...]
   */
  function _setManyTaxBPS(uint16[] calldata taxBPSArray) internal {
    uint256 numRanks = taxBPSArray.length;
    // early exit if no ranks
    if (numRanks == 0) return;
    if (numRanks > MAX_RANK_INDEX + 1) revert TooManyRanks(numRanks, MAX_RANK_INDEX + 1);

    uint256 defaultTaxBPS = taxBPSArray[0];
    uint256 newTaxBPSPerRanked;
    for (uint256 i; i < numRanks; ++i) {
      uint256 taxBPS = taxBPSArray[i];
      require(taxBPS <= BPS, InvalidTaxBPS(taxBPS, BPS)); // tax BPS must be in range of [0, 10000]
      require(taxBPS <= defaultTaxBPS, InvalidDefaultTaxBPS(defaultTaxBPS)); // Default tax must be the highest tax BPS

      newTaxBPSPerRanked |= uint256(taxBPS) << (16 * i);
      emit TaxBPSPerRankedUpdated(i, taxBPS);
    }

    // assign the number of ranks to the last 16 bits
    newTaxBPSPerRanked |= numRanks << 240;

    _taxBPSPerRanked = newTaxBPSPerRanked;
  }

  /**
   * @dev Build the type hash for verifying the tax oracle signature.
   */
  function _buildTaxOracleTypeHash(
    AxieScoreRanked memory axieScoreRanked,
    uint256 sellAmount,
    uint256 deadline,
    uint256 userNonce,
    uint256 masterNonce
  ) internal pure returns (bytes32) {
    return keccak256(
      abi.encode(
        TAX_ORACLE_TYPE_HASH, _buildAxieScoreTypeHash(axieScoreRanked), sellAmount, deadline, userNonce, masterNonce
      )
    );
  }

  /**
   * @dev Build the type hash for the axie score struct.
   */
  function _buildAxieScoreTypeHash(AxieScoreRanked memory axieScoreRanked) internal pure returns (bytes32) {
    return keccak256(
      abi.encode(AXIE_SCORE_RANKED_TYPE_HASH, axieScoreRanked.user, axieScoreRanked.rank, axieScoreRanked.axieScore)
    );
  }
}
