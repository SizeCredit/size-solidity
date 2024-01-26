// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract UserProxy is Initializable, OwnableUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner) external initializer {
        __Ownable_init(owner);
    }

    function proxy(address target, bytes memory data)
        public
        onlyOwner
        returns (bool success, bytes memory returnData)
    {
        if (target == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        (success, returnData) = address(target).call(data);
    }

    function proxy(address target, bytes memory data, uint256 _value)
        public
        onlyOwner
        returns (bool success, bytes memory returnData)
    {
        if (target == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        (success, returnData) = address(target).call{value: _value}(data);
    }

    function proxy(address[] memory targets, bytes[] memory datas) public onlyOwner {
        if (targets.length != datas.length) {
            revert Errors.ARRAY_LENGTHS_MISMATCH();
        }
        bool success;
        for (uint256 i = 0; i < targets.length; i++) {
            // slither-disable-next-line calls-loop
            (success,) = address(targets[i]).call(datas[i]);
            if (!success) {
                revert Errors.PROXY_CALL_FAILED(targets[i], datas[i]);
            }
        }
    }

    receive() external payable {}
}
