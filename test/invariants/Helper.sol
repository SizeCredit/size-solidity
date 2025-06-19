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
        address[] memory vaults = new address[](16);
        vaults[0] = address(0);
        vaults[1] = address(vault);
        vaults[2] = address(vault2);
        vaults[3] = address(vault3);
        vaults[4] = address(vaultMaliciousWithdrawNotAllowed);
        vaults[5] = address(vaultMaliciousReentrancy);
        vaults[6] = address(vaultMaliciousReentrancyGeneric);
        vaults[7] = address(vaultFeeOnTransfer);
        vaults[8] = address(vaultFeeOnEntryExit);
        vaults[9] = address(vaultLimits);
        vaults[10] = address(vaultNonERC4626);
        vaults[11] = address(vaultERC7540FullyAsync);
        vaults[12] = address(vaultERC7540ControlledAsyncDeposit);
        vaults[13] = address(vaultERC7540ControlledAsyncRedeem);
        vaults[14] = address(vaultInvalidUnderlying);
        vaults[15] = address(v);

        return vaults[uint256(uint160(v)) % vaults.length];
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
