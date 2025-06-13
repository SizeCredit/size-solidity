// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Asserts} from "@chimera/Asserts.sol";
import "@crytic/properties/contracts/util/Hevm.sol";
import {Deploy} from "@script/Deploy.sol";
import {Bounds} from "@test/invariants/Bounds.sol";

abstract contract ERC20TargetFunctions is Deploy, Bounds, Asserts {
    function mint(address token, address to, uint256 amount) public {
        if (uint160(token) % 2 == 0) {
            amount = between(amount, 0, MAX_AMOUNT_WETH / 100);
            hevm.deal(address(this), amount);
            weth.deposit{value: amount}();
            weth.transfer(to, amount);
        } else {
            amount = between(amount, 0, MAX_AMOUNT_USDC / 100);
            usdc.mint(to, amount);
        }
    }

    function burn(address token, address from, uint256 amount) public {
        if (uint160(token) % 2 == 0) {
            hevm.prank(from);
            weth.withdraw(amount);
            address(0).call{value: amount}("");
        } else {
            amount = between(amount, 0, MAX_AMOUNT_USDC / 100);
            usdc.burn(from, amount);
        }
    }

    receive() external payable {}
}
