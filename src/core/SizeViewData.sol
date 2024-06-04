// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {User} from "@src/core/SizeStorage.sol";
import {NonTransferrableScaledToken} from "@src/core/token/NonTransferrableScaledToken.sol";
import {NonTransferrableToken} from "@src/core/token/NonTransferrableToken.sol";

struct UserView {
    User user;
    address account;
    uint256 collateralTokenBalance;
    uint256 borrowATokenBalance;
    uint256 debtBalance;
}

struct DataView {
    uint256 nextDebtPositionId;
    uint256 nextCreditPositionId;
    IERC20Metadata underlyingCollateralToken;
    IERC20Metadata underlyingBorrowToken;
    NonTransferrableToken collateralToken;
    NonTransferrableScaledToken borrowAToken;
    NonTransferrableToken debtToken;
    IPool variablePool;
}
