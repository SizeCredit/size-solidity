// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {MulticallUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";

contract UserProxy is Initializable, OwnableUpgradeable, MulticallUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner) external initializer {
        __Ownable_init(owner);
        __Multicall_init();
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

    receive() external payable {}
}
