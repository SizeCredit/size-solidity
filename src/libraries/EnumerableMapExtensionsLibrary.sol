// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

library EnumerableMapExtensionsLibrary {
    using EnumerableMap for EnumerableMap.UintToUintMap;

    function increment(
        EnumerableMap.UintToUintMap storage self,
        uint256 key,
        uint256 value
    ) public returns (bool) {
        return self.set(key, self.get(key) + value);
    }

    function decrement(
        EnumerableMap.UintToUintMap storage self,
        uint256 key,
        uint256 value
    ) public returns (bool) {
        return self.set(key, self.get(key) - value);
    }

    function values(
        EnumerableMap.UintToUintMap storage self
    ) public view returns (uint256[] memory) {
        uint256 length = self.length();
        uint256[] memory result = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            (, result[i]) = self.at(i);
        }
        return result;
    }
}
