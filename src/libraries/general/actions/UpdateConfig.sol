// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {State} from "@src/SizeStorage.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Initialize, InitializeFixedParams} from "@src/libraries/general/actions/Initialize.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

struct UpdateConfigParams {
    bytes32 key;
    uint256 value;
}

library UpdateConfig {
    using Initialize for State;

    function validateUpdateConfig(State storage, UpdateConfigParams memory params) external pure {
        // validation is done at execution
    }

    function executeUpdateConfig(State storage state, UpdateConfigParams memory params) external {
        // TODO validate params
        if (params.key == "minimumCredit") {
            state._fixed.minimumCredit = params.value;
        } else {
            revert Errors.INVALID_KEY(params.key);
        }
    }
}
