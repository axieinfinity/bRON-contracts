// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

interface IbRONTaxAuthority {
  error LengthMismatch();
  error OnlyBRONCaller();
  error SellAmountZero();
  error InvalidSignature();
  error InvalidSellerAddress();
  error SignatureExpired();
  error TooManyRanks(uint256 numRanks, uint256 maxRanks);
  error EmptyRankList();
  error InvalidDefaultTaxBPS(uint256 defaultTaxBPS);
  error InvalidRank(uint256 rank, uint256 maxRank);
  error InvalidTaxBPS(uint256 taxBPS, uint256 maxTaxBPS);

  event TaxBPSPerRankedUpdated(uint256 rank, uint256 taxBPS);
  event FallbackTaxBPSUpdated(uint256 fallbackTaxBPS);

  /// @dev Operator should sign on this data to determine the tax BPS for the sell.
  struct AxieScoreRanked {
    address user;
    uint8 rank;
    uint256 axieScore;
  }

  /// @dev Return the BPS. Always 10000 = 100%
  function BPS() external view returns (uint256);

  /// @dev Return the bRON token.
  function bRON() external view returns (address);

  /// @dev Return the tax BPS per ranked.
  function getTaxBPSPerRanked(uint8 rank) external view returns (uint16);

  /// @dev Return the number of ranks.
  function getNumberOfRanks() external view returns (uint256);

  /// @dev Return all tax BPS per ranked.
  function getAllTaxBPSPerRanked() external view returns (uint16[] memory taxBPSArray);

  /**
   * @notice Set the tax BPS per ranked.
   * @dev Only callable by the operator.
   *
   * @param taxBPSArray The tax BPS per ranked. Result in range of [0, 10000].
   *
   * Emits {TaxBPSPerRankedUpdated} event.
   */
  function setTaxBPSPerRanked(uint16[] calldata taxBPSArray) external;

  /**
   * @notice Invalidate the unordered nonce.
   * @dev Only callable by the operator.
   *
   * @param user The user to invalidate the nonce.
   * @param nonce The nonce to invalidate.
   */
  function invalidateUnorderedNonce(address user, uint256 nonce) external;

  /**
   * @notice Get the sell tax percentage. This function is used to calculate the tax BPS for the sell.
   * @dev If this interface changes, the `bRON` contract should be updated to support the new interface.
   * @dev If the `extraData` is empty, the highest tax is applied.
   * @dev If the `extraData` is not empty, extraData should be encoded of the signing data and the signature.
   * @dev Revert if the signature is invalid, expired, or used nonce.
   *
   * @param seller The seller of the tokens.
   * @param sellAmount The amount of tokens to sell.
   * @param extraData The extra data for the tax oracle.
   * @return taxBPS The tax BPS. Result in range of [0, 10000].
   */
  function determineSellTaxBPS(address seller, uint256 sellAmount, bytes calldata extraData)
    external
    returns (uint16 taxBPS);
}
