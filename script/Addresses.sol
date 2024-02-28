// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

abstract contract Addresses {
    error InvalidChain(string chain);

    struct AddressInfo {
        address weth;
        address usdc;
    }

    function addresses(string memory chain) public pure returns (AddressInfo memory) {
        if (Strings.equal(chain, "sepolia")) {
            return AddressInfo({
                weth: 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14,
                usdc: 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8
            });
        } else {
            revert InvalidChain(chain);
        }
    }
}
