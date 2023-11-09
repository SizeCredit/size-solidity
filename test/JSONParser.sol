// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./OrderbookTestStorage.sol";

struct Operation {
    string method;
    string[] params;
    string sender;
}

contract JSONParser is Test, OrderbookTestStorage {
    using Strings for string;

    error NotFound(string);

    function parse(string memory filename) internal view returns (Operation[] memory operations) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, filename);
        string memory json = vm.readFile(path);
        bytes memory parsed = vm.parseJson(json);
        operations = abi.decode(parsed, (Operation[]));
        for (uint256 i = 0; i < operations.length; ++i) {
            console2.log("function", operations[i].method);
            console2.log("sender", operations[i].sender);
            for (uint256 j = 0; j < operations[i].params.length; ++j) {
                console2.log("params[]", operations[i].params[j]);
            }
        }
    }

    function execute(Operation[] memory operation) internal {
        for (uint256 i = 0; i < operation.length; ++i) {
            execute(operation[i]);
        }
    }

    function execute(Operation memory operation) internal {
        address sender = getSender(operation);
        (address target, bytes memory data) = getTargetAndCalldata(operation);

        call(sender, target, data);
    }

    function call(address sender, address target, bytes memory data) internal {
        vm.prank(sender);
        (bool success,) = target.call(data);
        require(success);
    }

    function getSender(Operation memory operation) internal view returns (address) {
        if (operation.sender.equal("alice")) {
            return alice;
        } else if (operation.sender.equal("bob")) {
            return bob;
        } else if (operation.sender.equal("candy")) {
            return candy;
        } else if (operation.sender.equal("james")) {
            return james;
        } else if (operation.sender.equal("liquidator")) {
            return liquidator;
        } else if (operation.sender.equal("admin")) {
            return address(this);
        } else {
            revert NotFound(operation.sender);
        }
    }

    function getTargetAndCalldata(Operation memory operation)
        internal
        view
        returns (address target, bytes memory data)
    {
        if (operation.method.equal("setPrice")) {
            target = address(priceFeed);
            data = abi.encodeWithSelector(priceFeed.setPrice.selector, toUint256(operation.params[0]));
        } else if (operation.method.equal("deposit")) {
            target = address(orderbook);
            data = abi.encodeWithSelector(
                orderbook.deposit.selector, toUint256(operation.params[0]), toUint256(operation.params[1])
            );
        }
    }

    function toUint256(string memory s) internal view returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        uint256 exponent = 0;
        for (uint256 i = 0; i < b.length; i++) {
            if (uint8(b[i]) >= 48 && uint8(b[i]) <= 57) {
                result = result * 10 + (uint256(uint8(b[i])) - 48);
            } else if (uint8(b[i]) == 101) {
                // e
                while (i < b.length - 1) {
                    i++;
                    exponent = exponent * 10 + (uint256(uint8(b[i])) - 48);
                }
            }
        }
        return result * 10 ** exponent;
    }
}
