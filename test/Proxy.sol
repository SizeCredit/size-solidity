// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

contract Proxy {
    address public immutable implementation;

    constructor(address _implementation) {
        implementation = _implementation;
    }

    fallback() external payable {
        (bool success, bytes memory returnData) = implementation.delegatecall(msg.data);
        require(success, "Delegatecall failed");
        assembly {
            return(add(returnData, 0x20), mload(returnData))
        }
    }

    receive() external payable {}
}
