// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {PropertiesConstants} from "@crytic/properties/contracts/util/PropertiesConstants.sol";
import {CREDIT_POSITION_ID_START, RESERVED_ID} from "@src/libraries/LoanLibrary.sol";

import {Deploy} from "@script/Deploy.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";
import {Bounds} from "@test/invariants/Bounds.sol";

import {PERCENT} from "@src/libraries/Math.sol";

abstract contract Helper is Deploy, PropertiesConstants, Bounds {
    function _getRandomUser(address user) internal pure returns (address) {
        return uint160(user) % 3 == 0 ? USER1 : uint160(user) % 3 == 1 ? USER2 : USER3;
    }

    function _getCreditPositionId(uint256 creditPositionId) internal view returns (uint256) {
        (, uint256 creditPositionsCount) = size.getPositionsCount();
        if (creditPositionsCount == 0) return RESERVED_ID;

        uint256 creditPositionIdIndex = creditPositionId % creditPositionsCount;
        return creditPositionId % PERCENT < PERCENTAGE_OLD_CREDIT
            ? CREDIT_POSITION_ID_START + creditPositionIdIndex
            : RESERVED_ID;
    }

    function _getRandomYieldCurve(uint256 seed) internal pure returns (YieldCurve memory) {
        return YieldCurveHelper.getRandomYieldCurve(seed);
    }
}
