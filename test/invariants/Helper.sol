// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {PropertiesConstants} from "@crytic/properties/contracts/util/PropertiesConstants.sol";
import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {Deploy} from "@test/Deploy.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

abstract contract Helper is Deploy, PropertiesConstants {
    uint256 internal constant MAX_AMOUNT_USDC = 3 * 100_000e6;
    uint256 internal constant MAX_AMOUNT_WETH = 3 * 100e18;
    uint256 internal constant MAX_DURATION = 180 days;
    uint256 internal constant MAX_RATE = 2e18;
    uint256 internal constant MAX_TIME_BUCKETS = 24;
    uint256 internal constant MIN_PRICE = 0.01e18;
    uint256 internal constant MAX_PRICE = 10_000e18;

    function _getRandomUser(address user) internal pure returns (address) {
        return uint160(user) % 3 == 0 ? USER1 : uint160(user) % 3 == 1 ? USER2 : USER3;
    }

    function _getRandomYieldCurve(uint256 seed) internal pure returns (YieldCurve memory) {
        return YieldCurveHelper.getRandomYieldCurve(seed);
    }

    function _getRandomVirtualCollateralFixedLoanIds(uint256 n, uint256 seed)
        internal
        view
        returns (uint256[] memory virtualCollateralFixedLoanIds)
    {
        uint256 activeFixedLoans = size.activeFixedLoans();
        virtualCollateralFixedLoanIds = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            uint256 index = uint256(keccak256(abi.encodePacked(seed, i))) % activeFixedLoans;
            virtualCollateralFixedLoanIds[i] = index;
        }
    }
}
