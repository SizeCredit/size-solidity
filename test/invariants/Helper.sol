// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {PropertiesConstants} from "@crytic/properties/contracts/util/PropertiesConstants.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";
import {YieldCurveHelper} from "@test/helpers/YieldCurveHelper.sol";

abstract contract Helper is PropertiesConstants {
    function _getRandomUser(address user) internal pure returns (address) {
        return uint160(user) % 3 == 0 ? USER1 : uint160(user) % 3 == 1 ? USER2 : USER3;
    }

    function _getRandomYieldCurve(uint256 seed) internal pure returns (YieldCurve memory) {
        if (seed % 5 == 0) {
            return YieldCurveHelper.normalCurve();
        } else if (seed % 5 == 1) {
            return YieldCurveHelper.flatCurve();
        } else if (seed % 5 == 2) {
            return YieldCurveHelper.invertedCurve();
        } else if (seed % 5 == 3) {
            return YieldCurveHelper.humpedCurve();
        } else if (seed % 5 == 4) {
            return YieldCurveHelper.steepCurve();
        } else {
            return YieldCurveHelper.negativeCurve();
        }
    }
}
