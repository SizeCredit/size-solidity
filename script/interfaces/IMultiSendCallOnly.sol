// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

// https://github.com/safe-global/safe-smart-account/blob/a1e7f4a763952f5b116a8ab4c7361b95de2083c3/contracts/libraries/MultiSendCallOnly.sol
interface IMultiSendCallOnly {
    function multiSend(bytes memory transactions) external payable;
}
