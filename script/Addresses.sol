// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

abstract contract Addresses {
    error InvalidChain(string chain);

    struct AddressInfo {
        address variablePool;
        address weth;
        address usdc;
    }

    function addresses(string memory chain) public pure returns (AddressInfo memory) {
        if (Strings.equal(chain, "sepolia")) {
            return AddressInfo({
                variablePool: 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951,
                weth: 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14,
                usdc: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
            });
        } else {
            revert InvalidChain(chain);
        }
    }
}
