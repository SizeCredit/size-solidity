// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

abstract contract ReentrancyGuardUpgradeableWithViewModifier is ReentrancyGuardUpgradeable {
    /// @dev See https://github.com/OpenZeppelin/openzeppelin-contracts/issues/4422
    modifier nonReentrantView() {
        if (_reentrancyGuardEntered()) {
            revert ReentrancyGuardReentrantCall();
        }
        _;
    }
}
