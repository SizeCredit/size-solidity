// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {PropertiesConstants} from "@crytic/properties/contracts/util/PropertiesConstants.sol";
import {CREDIT_POSITION_ID_START, RESERVED_ID} from "@src/libraries/fixed/LoanLibrary.sol";

import {Deploy} from "@script/Deploy.sol";
import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {PERCENT} from "@src/libraries/Math.sol";

abstract contract Helper is Deploy, PropertiesConstants {
    uint256 internal MAX_AMOUNT_USDC = 3 * 100_000e6;
    uint256 internal MAX_AMOUNT_WETH = 3 * 100e18;
    uint256 internal MAX_DURATION = 10 * 365 days;
    uint256 internal MIN_PRICE = 0.01e18;
    uint256 internal MAX_PRICE = 20_000e18;
    uint256 internal MAX_LIQUIDITY_INDEX_INCREASE_PERCENT = 1.05e18;
    uint256 internal MAX_BORROW_RATE = 2e18;
    uint256 internal PERCENTAGE_OLD_CREDIT = 0.5e18;

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
