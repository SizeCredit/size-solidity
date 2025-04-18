// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";

import {NonTransferrableScaledTokenV1} from "@deprecated/token/NonTransferrableScaledTokenV1.sol";
import {NonTransferrableScaledTokenV1_2} from "@deprecated/token/NonTransferrableScaledTokenV1_2.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import {SimplePool} from "@test/local/token/differential/mocks/SimplePool.sol";
import {USDC} from "@test/mocks/USDC.sol";

import {Test} from "forge-std/Test.sol";

/// @custom:halmos --storage-layout=generic --array-lengths senders=2 --loop 256
contract NonTransferrableScaledTokenDifferentialTest is Test, SymTest {
    NonTransferrableScaledTokenV1 public v1;
    NonTransferrableScaledTokenV1_2 public v1_2;

    address owner = address(0x2);
    USDC public underlying;
    IPool public pool;

    function setUp() public {
        underlying = new USDC(address(this));
        pool = IPool(address(new SimplePool()));
        v1 = new NonTransferrableScaledTokenV1(pool, IERC20Metadata(underlying), owner, "Test", "TEST", 18);
        v1_2 = new NonTransferrableScaledTokenV1_2(pool, IERC20Metadata(underlying), owner, "Test", "TEST", 18);
    }

    // halmos does not complete
    function _check_NonTransferrableToken_differential(address[] memory senders) private {
        bytes[] memory calls = new bytes[](senders.length);
        for (uint256 i = 0; i < senders.length; i++) {
            calls[i] = svm.createCalldata("INonTransferrableScaledTokenV1Call");
        }
        bytes memory staticcall = svm.createCalldata("INonTransferrableScaledTokenStaticcall", true);
        test_NonTransferrableToken_differential(senders, calls, staticcall, false);
    }

    function test_NonTransferrableToken_differential(
        address[] memory senders,
        bytes[] memory calls,
        bytes memory staticcall,
        bool shouldCheckFailedCall
    ) public {
        if (senders.length != calls.length) {
            return;
        }
        for (uint256 i = 0; i < senders.length; i++) {
            vm.assume(senders[i] != address(0));
        }

        address[2] memory contracts = [address(v1), address(v1_2)];
        bool[2] memory successes;
        bytes[2] memory results;

        for (uint256 j = 0; j < calls.length; j++) {
            for (uint256 i = 0; i < contracts.length; i++) {
                vm.prank(senders[j]);
                (bool _success, bytes memory _result) = contracts[i].call(calls[j]);
                if (!shouldCheckFailedCall) {
                    vm.assume(_success);
                }
                successes[i] = _success;
                results[i] = _result;
            }
        }

        verifyResults(successes, results);

        for (uint256 i = 0; i < contracts.length; i++) {
            (bool _success, bytes memory _result) = contracts[i].staticcall(staticcall);
            successes[i] = _success;
            results[i] = _result;
        }

        verifyResults(successes, results);
    }

    function verifyResults(bool[2] memory successes, bytes[2] memory results) private pure {
        for (uint256 i = 0; i < successes.length - 1; i++) {
            // if (successes[i] != successes[i + 1]) {
            //     console.logBool(successes[i]);
            //     console.logBool(successes[i + 1]);
            //     console.logBytes(results[i]);
            //     console.logBytes(results[i + 1]);
            //     console.log("");
            // }
            assertEq(successes[i], successes[i + 1]);
            if (successes[i]) {
                // if (keccak256(results[i]) != keccak256(results[i + 1])) {
                //     console.logBool(successes[i]);
                //     console.logBool(successes[i + 1]);
                //     console.logBytes(results[i]);
                //     console.logBytes(results[i + 1]);
                //     console.log("");
                // }

                assertEq(results[i], results[i + 1]);
            }
        }
    }
}
