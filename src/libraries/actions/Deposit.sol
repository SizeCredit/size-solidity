// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {SizeStorage} from "@src/SizeStorage.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";
import {OfferLibrary, BorrowOffer} from "@src/libraries/OfferLibrary.sol";
import {LoanLibrary, Loan} from "@src/libraries/LoanLibrary.sol";
import {VaultLibrary, Vault} from "@src/libraries/VaultLibrary.sol";
import {SizeView} from "@src/SizeView.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ISize} from "@src/interfaces/ISize.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";

struct DepositParams {
    address user;
    address token;
    uint256 value;
}

library Deposit {
    using LoanLibrary for Loan;
    using VaultLibrary for Vault;
    using SafeERC20 for IERC20Metadata;

    function validateDeposit(State storage state, DepositParams memory params) external view {
        // validte user

        // validate token
        if (params.token != address(state.collateralAsset) && params.token != address(state.borrowAsset)) {
            revert Errors.INVALID_TOKEN(params.token);
        }

        // validate value
        if (params.value == 0) {
            revert Errors.NULL_AMOUNT();
        }
    }

    function executeDeposit(State storage state, DepositParams memory params) external {
        uint256 wad = VaultLibrary.valueToWad(params.value, IERC20Metadata(params.token).decimals());
        if (params.token == address(state.collateralAsset)) {
            state.users[params.user].collateralAsset.free += wad;
            state.collateralAsset.safeTransferFrom(params.user, address(this), params.value);
        } else {
            state.users[params.user].borrowAsset.free += wad;
            state.borrowAsset.safeTransferFrom(params.user, address(this), params.value);
        }
    }
}
