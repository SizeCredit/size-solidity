// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPool} from "@aave/interfaces/IPool.sol";
import {IAToken} from "@aave/interfaces/IAToken.sol";
import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";
import {User} from "@src/libraries/fixed/UserLibrary.sol";

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
    IPool variablePool;
    NonTransferrableToken collateralToken;
    IAToken borrowAToken;
    NonTransferrableToken debtToken;
}