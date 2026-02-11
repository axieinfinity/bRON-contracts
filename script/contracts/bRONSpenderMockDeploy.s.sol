// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Contract } from "../utils/Contract.sol";
import { ISharedArgument } from "../interfaces/ISharedArgument.sol";
import { Migration } from "../Migration.s.sol";
import { bRONSpenderMock } from "../../src/mocks/bRONSpenderMock.sol";

contract bRONSpenderMockDeploy is Migration {
  function run() public virtual returns (bRONSpenderMock) {
    ISharedArgument.bRONSpenderMockParameter memory param = config.sharedArguments().bRONSpenderMock;
    return bRONSpenderMock(
      _deployProxy(
        Contract.bRONSpenderMock.key(),
        abi.encodeCall(
          bRONSpenderMock.initialize,
          (param.admin, loadContract(Contract.bRON.key()), param.treasury)
        )
      )
    );
  }
}
