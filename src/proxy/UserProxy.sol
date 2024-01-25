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

    function proxy(address _target, bytes memory _calldata)
        public
        onlyOwner
        returns (bool success, bytes memory returnData)
    {
        (success, returnData) = address(_target).call(_calldata);
    }

    function proxy(address _target, bytes memory _calldata, uint256 _value)
        public
        onlyOwner
        returns (bool success, bytes memory returnData)
    {
        (success, returnData) = address(_target).call{value: _value}(_calldata);
    }

    function proxy(address[] memory _targets, bytes[] memory _calldatas) public onlyOwner {
        if (_targets.length != _calldatas.length) {
            revert Errors.ARRAY_LENGTHS_MISMATCH();
        }
        bool success;
        for (uint256 i = 0; i < _targets.length; i++) {
            (success,) = address(_targets[i]).call(_calldatas[i]);
            if (!success) {
                revert Errors.PROXY_CALL_FAILED(_targets[i], _calldatas[i]);
            }
        }
    }

    receive() external payable {}
}
