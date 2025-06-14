// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {PropertiesConstants} from "@crytic/properties/contracts/util/PropertiesConstants.sol";
import {CREDIT_POSITION_ID_START, RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";

import {Deploy} from "@script/Deploy.sol";
import {YieldCurve} from "@src/market/libraries/YieldCurveLibrary.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";
import {Bounds} from "@test/invariants/Bounds.sol";

import {PERCENT} from "@src/market/libraries/Math.sol";

abstract contract Helper is Deploy, PropertiesConstants, Bounds {
    function _getRandomUser(address user) internal pure returns (address) {
        return uint160(user) % 3 == 0 ? USER1 : uint160(user) % 3 == 1 ? USER2 : USER3;
    }

    function _getRandomVault(address v) internal view returns (address) {
        uint256 branches = 14;
        if (uint160(v) % branches == 0) {
            return address(0);
        } else if (uint160(v) % branches == 1) {
            return address(vault);
        } else if (uint160(v) % branches == 2) {
            return address(vault2);
        } else if (uint160(v) % branches == 3) {
            return address(vault3);
        } else if (uint160(v) % branches == 4) {
            return address(vaultMalicious);
        } else if (uint160(v) % branches == 5) {
            return address(vaultFeeOnTransfer);
        } else if (uint160(v) % branches == 6) {
            return address(vaultFeeOnEntryExit);
        } else if (uint160(v) % branches == 7) {
            return address(vaultLimits);
        } else if (uint160(v) % branches == 8) {
            return address(vaultNonERC4626);
        } else if (uint160(v) % branches == 9) {
            return address(vaultERC7540FullyAsync);
        } else if (uint160(v) % branches == 10) {
            return address(vaultERC7540ControlledAsyncDeposit);
        } else if (uint160(v) % branches == 11) {
            return address(vaultERC7540ControlledAsyncRedeem);
        } else if (uint160(v) % branches == 12) {
            return address(vaultInvalidUnderlying);
        } else {
            return address(v);
        }
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
