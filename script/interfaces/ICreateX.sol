// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface ICreateX {
    function deployCreate2(bytes32 salt, bytes memory initCode) external payable returns (address newContract);
    function computeCreate2Address(bytes32 salt, bytes32 initCodeHash)
        external
        view
        returns (address computedAddress);
}
