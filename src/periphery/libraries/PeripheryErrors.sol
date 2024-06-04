// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

/// @title PeripheryErrors
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
library PeripheryErrors {
    error INVALID_SWAP_METHOD();
    error NOT_AAVE_POOL();
    error NOT_INITIATOR();
    error INSUFFICIENT_BALANCE();
}
