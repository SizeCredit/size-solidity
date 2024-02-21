// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {Errors} from "@src/libraries/Errors.sol";

/// @title Vault
/// @notice A contract that permits the owner to execute arbitrary calls
/// @dev This contract is deployed behind minimal proxy contracts, also known as "clones", using OpenZeppelin's Clones library.
///      Because of that, it is not possible to use the `constructor`, so the `initialize` function is used instead.
contract Vault is Initializable, OwnableUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner) external initializer {
        __Ownable_init(owner);
    }

    function proxy(address target, bytes memory data) public onlyOwner returns (bytes memory returnData) {
        if (target == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        bool success;
        (success, returnData) = address(target).call(data);
        if (!success) {
            revert Errors.PROXY_CALL_FAILED(target, data);
        }
    }

    function proxy(address target, bytes memory data, uint256 value)
        public
        onlyOwner
        returns (bytes memory returnData)
    {
        if (target == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        bool success;
        (success, returnData) = address(target).call{value: value}(data);
        if (!success) {
            revert Errors.PROXY_CALL_FAILED(target, data);
        }
    }

    function proxy(address[] memory targets, bytes[] memory datas) public onlyOwner returns (bytes[] memory results) {
        if (targets.length != datas.length) {
            revert Errors.ARRAY_LENGTHS_MISMATCH();
        }

        results = new bytes[](datas.length);
        bool success;
        for (uint256 i = 0; i < targets.length; i++) {
            if (targets[i] == address(0)) {
                revert Errors.NULL_ADDRESS();
            }
            // slither-disable-next-line calls-loop
            (success, results[i]) = address(targets[i]).call(datas[i]);
            if (!success) {
                revert Errors.PROXY_CALL_FAILED(targets[i], datas[i]);
            }
        }
    }

    receive() external payable {}
}
