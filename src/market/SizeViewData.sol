// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {User} from "@src/market/SizeStorage.sol";

import {NonTransferrableToken} from "@src/market/token/NonTransferrableToken.sol";
import {Vault} from "@src/market/token/Vault.sol";

struct UserView {
    // The user struct
    User user;
    // The user's account address
    address account;
    // The user's collateral token balance
    uint256 collateralTokenBalance;
    // The user's borrow token balance
    uint256 borrowTokenBalance;
    // The user's debt token balance
    uint256 debtBalance;
}

struct DataView {
    // The next debt position ID
    uint256 nextDebtPositionId;
    // The next credit position ID
    uint256 nextCreditPositionId;
    // The underlying collateral token
    IERC20Metadata underlyingCollateralToken;
    // The underlying borrow token
    IERC20Metadata underlyingBorrowToken;
    // The collateral token
    NonTransferrableToken collateralToken;
    // The default borrow token vault
    Vault defaultBorrowTokenVault;
    // The debt token
    NonTransferrableToken debtToken;
    // The variable pool
    IPool variablePool;
}
