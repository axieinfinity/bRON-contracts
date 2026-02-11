// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { ERC165, IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { ERC20OpenZeppelin } from "@limitbreak-creator-token-standard-v5-5.0.0/token/erc20/ERC20OpenZeppelin.sol";
import { ERC20C } from "@limitbreak-creator-token-standard-v5-5.0.0/erc20c/ERC20C.sol";
import { IbRON } from "./interfaces/IbRON.sol";
import { IERC20Spendable } from "./interfaces/IERC20Spendable.sol";
import { IbRONTaxAuthority } from "./interfaces/IbRONTaxAuthority.sol";

contract bRON is Initializable, Ownable2Step, Pausable, ReentrancyGuard, ERC20C, IbRON {
  using Math for uint256;

  uint96 public constant override PAIRED_PRICE_PER_TOKEN_NUMERATOR = 10000_00;
  uint96 public constant override PAIRED_PRICE_PER_TOKEN_DENOMINATOR = 10000_00;
  uint16 public constant override BPS = 100_00;

  /// @notice The WRON token (Wrapped RON).
  IERC20 public immutable override WRON;

  /// @dev Reserved storage slots.
  uint256[50] private __gap;
  address internal _bRONTaxAuthority;
  mapping(address => bool) internal _whitelistedSpenders;
  address internal _taxTreasury;

  constructor(address WRON_) ERC20OpenZeppelin("Bonded RON", "bRON", 18) {
    WRON = IERC20(WRON_);

    // renounce ownership to prevent deployer from tampering on the implementation contract.
    renounceOwnership();
    _disableInitializers();
  }

  function initialize(address owner_, address taxAuthority_, address taxTreasury_) public initializer {
    _setNameSymbolAndDecimals("Bonded RON", "bRON", 18);
    _setTaxAuthority(taxAuthority_);
    _setTaxTreasury(taxTreasury_);
    _transferOwnership(owner_);
  }

  modifier nonZeroAmount(uint256 amount) {
    _requireNonZeroAmount(amount);
    _;
  }

  modifier nonZeroAddress(address addr) {
    _requireNonZeroAddress(addr);
    _;
  }

  /// @dev Pause the contract.
  function pause() external onlyOwner {
    _pause();
  }

  /// @dev Unpause the contract.
  function unpause() external onlyOwner {
    _unpause();
  }

  /// @inheritdoc IERC165
  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == type(IbRON).interfaceId || interfaceId == type(IERC20Spendable).interfaceId
      || super.supportsInterface(interfaceId);
  }

  /// @inheritdoc IbRON
  function buyTokens(address recipient, uint256 buyAmount)
    external
    whenNotPaused
    nonZeroAmount(buyAmount)
    nonZeroAddress(recipient)
    returns (uint256 actualPairedIn)
  {
    actualPairedIn = _calculatePairedIn(buyAmount);

    emit TokenBought(_msgSender(), recipient, actualPairedIn, buyAmount);
    _mint(recipient, buyAmount);
    _transferFromPairedToken(_msgSender(), address(this), actualPairedIn);
  }

  /// @inheritdoc IbRON
  function sellTokens(uint256 sellAmount, uint256 minAmountOut, bytes calldata extraData)
    external
    whenNotPaused
    nonReentrant
    nonZeroAmount(sellAmount)
    returns (uint256 actualPairedOut)
  {
    uint256 taxBPS = getTaxAuthority()
      .determineSellTaxBPS({ seller: _msgSender(), sellAmount: sellAmount, extraData: extraData });
    _requireValidBPS(taxBPS);

    actualPairedOut = _calculatePairedOut({ amountIn: sellAmount, taxBPS: taxBPS });
    uint256 amountPairedToCreatorShare = sellAmount - actualPairedOut;

    require(actualPairedOut >= minAmountOut, CompromisedSlippageProtection());

    emit TokenSold(_msgSender(), _msgSender(), sellAmount, actualPairedOut);
    _burn(_msgSender(), sellAmount);
    _transferPairedToken(_msgSender(), actualPairedOut);
    _transferPairedToken(getTaxTreasury(), amountPairedToCreatorShare);
  }

  /// @inheritdoc IERC20Spendable
  function spendTokens(address tokenOwner, uint256 amount, address recipient)
    external
    whenNotPaused
    nonZeroAmount(amount)
    nonZeroAddress(recipient)
  {
    address spender = _msgSender();
    require(isWhitelistedSpender(spender), NotWhitelistedSpender(spender));
    require(recipient != tokenOwner, SpendToSelf());

    emit TokenSpent(spender, tokenOwner, recipient, amount);
    _burn(tokenOwner, amount);
    _transferPairedToken(recipient, amount);
  }

  /// @inheritdoc IbRON
  function isWhitelistedSpender(address spender) public view returns (bool) {
    return _whitelistedSpenders[spender];
  }

  /// @inheritdoc IbRON
  function setWhitelistedSpenders(address[] calldata spenders, bool[] calldata isWhitelisted) external onlyOwner {
    uint256 length = spenders.length;
    require(length == isWhitelisted.length, LengthMismatch());
    for (uint256 i; i < length; ++i) {
      _whitelistedSpenders[spenders[i]] = isWhitelisted[i];
      emit SpenderWhitelisted(spenders[i], isWhitelisted[i]);
    }
  }

  /// @inheritdoc IbRON
  function withdrawOwnerShares(address recipient, uint256 amount) external onlyOwner nonZeroAmount(amount) {
    require(getCreatorShares() >= amount, InsufficientShares());
    _transferPairedToken(recipient, amount);

    emit SharesWithdrawn(recipient, amount);
  }

  /// @inheritdoc IbRON
  function getTaxAuthority() public view returns (IbRONTaxAuthority) {
    return IbRONTaxAuthority(_bRONTaxAuthority);
  }

  /// @inheritdoc IbRON
  function setTaxAuthority(address taxAuthority) external onlyOwner {
    _setTaxAuthority(taxAuthority);
  }

  /// @inheritdoc IbRON
  function getTaxTreasury() public view returns (address) {
    return _taxTreasury;
  }

  /// @inheritdoc IbRON
  function setTaxTreasury(address taxTreasury) external onlyOwner {
    _setTaxTreasury(taxTreasury);
  }

  /// @inheritdoc IbRON
  function getCreatorShares() public view returns (uint256) {
    uint256 wronLocked = WRON.balanceOf(address(this));
    uint256 bRONSupply = totalSupply();

    // Expect the WRON locked never less than the bRON supply.
    require(wronLocked >= bRONSupply, InsufficientWRONLocked());
    return wronLocked - bRONSupply;
  }

  /// @dev Override the `OwnablePermissions` to check whether the caller is the contract owner.
  function _requireCallerIsContractOwner() internal view virtual override {
    _checkOwner();
  }

  /// @dev Calculate the paired token amount to the pool for a given `tokenToBuy` amount.
  function _calculatePairedIn(uint256 amountOut) internal pure returns (uint256 amountPairedIn) {
    return amountOut.mulDiv(PAIRED_PRICE_PER_TOKEN_NUMERATOR, PAIRED_PRICE_PER_TOKEN_DENOMINATOR, Math.Rounding.Up);
  }

  /// @dev Calculate the paired token amount to the pool for a given `tokenToBuy` amount.
  function _calculatePairedOut(uint256 amountIn, uint256 taxBPS) internal pure returns (uint256 amountPairedOut) {
    uint96 numerator = PAIRED_PRICE_PER_TOKEN_NUMERATOR;
    uint96 denominator = PAIRED_PRICE_PER_TOKEN_DENOMINATOR;

    // amount out in theoretical value (without tax)
    uint256 amountOutBeforeTax = amountIn.mulDiv(numerator, denominator);

    // amount out after deducting tax
    amountPairedOut = amountOutBeforeTax.mulDiv(BPS - taxBPS, BPS);

    // Expect the amount paired out never greater than the amount in.
    require(amountPairedOut <= amountIn, InvalidPairedOut());
  }

  /// @dev Transfer `amount` of paired tokens from `from` to `to`.
  function _transferFromPairedToken(address from, address to, uint256 amount) internal {
    SafeERC20.safeTransferFrom(WRON, from, to, amount);
  }

  /// @dev Transfer `amount` of paired tokens to `to`.
  function _transferPairedToken(address to, uint256 amount) internal {
    SafeERC20.safeTransfer(WRON, to, amount);
  }

  /// @dev Override the `ERC20C` to add the pause check.
  function _beforeTokenTransfer(address from, address to, uint256 amount) internal override whenNotPaused {
    super._beforeTokenTransfer(from, to, amount);
  }

  /// @dev If `account` is not the caller, it should be approved before burning.
  function _burn(address account, uint256 amount) internal override {
    if (account != _msgSender()) {
      _spendAllowance(account, _msgSender(), amount);
    }
    super._burn(account, amount);
  }

  /// @dev Set the tax authority.
  function _setTaxAuthority(address taxAuthority) internal {
    _requireNonZeroAddress(taxAuthority);
    _bRONTaxAuthority = taxAuthority;
    emit TaxAuthoritySet(taxAuthority);
  }

  /// @dev Set the tax treasury.
  function _setTaxTreasury(address taxTreasury) internal {
    _requireNonZeroAddress(taxTreasury);
    _taxTreasury = taxTreasury;
    emit TaxTreasurySet(taxTreasury);
  }

  /// @dev Require the BPS to be valid.
  function _requireValidBPS(uint256 bps) internal pure {
    require(bps <= BPS, InvalidBPS(bps, BPS));
  }

  /// @dev Require the amount to be non-zero.
  function _requireNonZeroAmount(uint256 amount) internal pure {
    require(amount > 0, ZeroAmount());
  }

  /// @dev Require the address to be non-zero.
  function _requireNonZeroAddress(address addr) internal pure {
    require(addr != address(0), ZeroAddress());
  }
}
