// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";

import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {CryticAsserts} from "@chimera/CryticAsserts.sol";
import {vm} from "@chimera/Hevm.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {NonTransferrableScaledToken} from "@src/token/NonTransferrableScaledToken.sol";
import {NonTransferrableScaledTokenV1} from "@test/local/token/differential/NonTransferrableScaledTokenV1.sol";
import {INonTransferrableScaledTokenCall} from
    "@test/local/token/differential/interfaces/INonTransferrableScaledTokenCall.sol";
import {INonTransferrableScaledTokenStaticcall} from
    "@test/local/token/differential/interfaces/INonTransferrableScaledTokenStaticcall.sol";
import {SimplePool} from "@test/local/token/differential/mocks/SimplePool.sol";
import {USDC} from "@test/mocks/USDC.sol";

// echidna . --contract CryticNonTransferrableScaledTokenDifferentialCryticTester --config echidna.yaml
// medusa fuzz
contract CryticNonTransferrableScaledTokenDifferentialCryticTester is CryticAsserts {
    string private constant ERROR = "ERROR";

    NonTransferrableScaledTokenV1 private v1;
    NonTransferrableScaledToken private v2;
    USDC private underlying;
    IPool private pool;

    constructor() {
        underlying = new USDC(address(this));
        pool = IPool(address(new SimplePool()));
        v1 = new NonTransferrableScaledTokenV1(
            pool,
            IERC20Metadata(underlying),
            msg.sender,
            string.concat(underlying.name(), " Test"),
            string.concat(underlying.symbol(), " TEST"),
            underlying.decimals()
        );
        v2 = new NonTransferrableScaledToken(
            pool,
            IERC20Metadata(underlying),
            msg.sender,
            string.concat(underlying.name(), " Test"),
            string.concat(underlying.symbol(), " TEST"),
            underlying.decimals()
        );
    }

    // Helper function for regular calls
    function callFunction(address target1, address target2, bytes memory data) internal {
        vm.prank(msg.sender);
        (bool success1, bytes memory result1) = target1.call(data);

        vm.prank(msg.sender);
        (bool success2, bytes memory result2) = target2.call(data);

        t(success1 == success2, ERROR);
        if (success1) {
            t(keccak256(result1) == keccak256(result2), ERROR);
        }
    }

    function staticCallFunction(address target1, address target2, bytes memory data) internal {
        vm.prank(msg.sender);
        (bool success1, bytes memory result1) = target1.staticcall(data);

        vm.prank(msg.sender);
        (bool success2, bytes memory result2) = target2.staticcall(data);

        t(success1 == success2, ERROR);
        if (success1) {
            t(keccak256(result1) == keccak256(result2), ERROR);
        }
    }

    function mintScaled(address to, uint256 scaledAmount) external {
        callFunction(
            address(v1), address(v2), abi.encodeCall(INonTransferrableScaledTokenCall.mintScaled, (to, scaledAmount))
        );
    }

    function burnScaled(address from, uint256 scaledAmount) external {
        callFunction(
            address(v1), address(v2), abi.encodeCall(INonTransferrableScaledTokenCall.burnScaled, (from, scaledAmount))
        );
    }

    function transferFrom(address from, address to, uint256 value) external {
        callFunction(
            address(v1), address(v2), abi.encodeCall(INonTransferrableScaledTokenCall.transferFrom, (from, to, value))
        );
    }

    function transfer(address to, uint256 value) external {
        callFunction(address(v1), address(v2), abi.encodeCall(INonTransferrableScaledTokenCall.transfer, (to, value)));
    }

    function approve(address spender, uint256 value) external {
        callFunction(
            address(v1), address(v2), abi.encodeCall(INonTransferrableScaledTokenCall.approve, (spender, value))
        );
    }

    function allowance(address owner, address spender) external {
        staticCallFunction(
            address(v1), address(v2), abi.encodeCall(INonTransferrableScaledTokenStaticcall.allowance, (owner, spender))
        );
    }

    function scaledBalanceOf(address account) external {
        staticCallFunction(
            address(v1), address(v2), abi.encodeCall(INonTransferrableScaledTokenStaticcall.scaledBalanceOf, (account))
        );
    }

    function balanceOf(address account) external {
        staticCallFunction(
            address(v1), address(v2), abi.encodeCall(INonTransferrableScaledTokenStaticcall.balanceOf, (account))
        );
    }

    function scaledTotalSupply() external {
        staticCallFunction(
            address(v1), address(v2), abi.encodeCall(INonTransferrableScaledTokenStaticcall.scaledTotalSupply, ())
        );
    }

    function totalSupply() external {
        staticCallFunction(
            address(v1), address(v2), abi.encodeCall(INonTransferrableScaledTokenStaticcall.totalSupply, ())
        );
    }

    function liquidityIndex() external {
        staticCallFunction(
            address(v1), address(v2), abi.encodeCall(INonTransferrableScaledTokenStaticcall.liquidityIndex, ())
        );
    }
}
