// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { AccessControlEnumerable } from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import { bRONSpenderUpgradeable } from "../shared/bRONSpenderUpgradeable.sol";

contract bRONSpenderMock is Initializable, AccessControlEnumerable, bRONSpenderUpgradeable {
  address public treasury;

  constructor() {
    _disableInitializers();
  }

  function initialize(address admin, address bRON, address treasury_) public initializer {
    _grantRole(DEFAULT_ADMIN_ROLE, admin);

    _updateBRON(bRON);

    treasury = treasury_;
  }

  function updateBRON(address bRON) public onlyRole(DEFAULT_ADMIN_ROLE) {
    _updateBRON(bRON);
  }

  function spendTokens(uint256 amount, bool fallbackToWRON) public {
    _spendBRON(_msgSender(), amount, treasury, fallbackToWRON);
  }
}
