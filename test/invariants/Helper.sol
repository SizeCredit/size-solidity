// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {PropertiesConstants} from "@crytic/properties/contracts/util/PropertiesConstants.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";
import {Deploy} from "@test/Deploy.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

abstract contract Helper is Deploy, PropertiesConstants {
    uint256 internal constant MAX_AMOUNT_USDC = 3 * 100_000e6;
    uint256 internal constant MAX_AMOUNT_WETH = 3 * 100e18;
    uint256 internal constant MAX_TIMESTAMP = 2 * 365 days;
    uint256 internal constant MAX_RATE = 2e18;
    uint256 internal constant MAX_TIME_BUCKETS = 24;

    function _getRandomSender(address sender) internal pure returns (address) {
        return uint160(sender) % 3 == 0 ? USER1 : uint160(sender) % 3 == 1 ? USER2 : USER3;
    }

    function _getRandomYieldCurve(uint256 seed) internal pure returns (YieldCurve memory) {
        if (seed % 6 == 0) {
            return YieldCurveHelper.normalCurve();
        } else if (seed % 6 == 1) {
            return YieldCurveHelper.flatCurve();
        } else if (seed % 6 == 2) {
            return YieldCurveHelper.invertedCurve();
        } else if (seed % 6 == 3) {
            return YieldCurveHelper.humpedCurve();
        } else if (seed % 6 == 4) {
            return YieldCurveHelper.steepCurve();
        } else if (seed % 6 == 5) {
            return YieldCurveHelper.negativeCurve();
        } else {
            uint256 timeBucketsLength = seed % MAX_TIME_BUCKETS;
            uint256 rate = seed % MAX_RATE;
            return YieldCurveHelper.getFlatRate(timeBucketsLength, rate);
        }
    }

    function _getRandomVirtualCollateralLoanIds(uint256 n, uint256 seed)
        internal
        view
        returns (uint256[] memory virtualCollateralLoanIds)
    {
        uint256 activeLoans = size.activeLoans();
        virtualCollateralLoanIds = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            uint256 index = uint256(keccak256(abi.encodePacked(seed, i))) % activeLoans;
            virtualCollateralLoanIds[i] = index;
        }
    }
}
