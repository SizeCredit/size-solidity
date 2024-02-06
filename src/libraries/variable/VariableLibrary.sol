// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {IPool} from "@aave/interfaces/IPool.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {State} from "@src/SizeStorage.sol";
import {Events} from "@src/libraries/Events.sol";
import {CollateralLibrary} from "@src/libraries/fixed/CollateralLibrary.sol";

import {FixedLoan, FixedLoanLibrary} from "@src/libraries/fixed/FixedLoanLibrary.sol";

import {Vault} from "@src/proxy/Vault.sol";

// TODO: this library can be optimized to avoid unnecessary approvals when transferring tokens from Size to Size
library VariableLibrary {
    using SafeERC20 for IERC20Metadata;
    using CollateralLibrary for State;
    using FixedLoanLibrary for State;
    using FixedLoanLibrary for FixedLoan;

    function getVault(State storage state, address user) public returns (Vault) {
        if (address(state._fixed.users[user].vault) != address(0)) {
            return state._fixed.users[user].vault;
        }
        Vault vault = Vault(payable(Clones.clone(state._variable.vaultImplementation)));
        emit Events.CreateVault(user, address(vault));
        vault.initialize(address(this));
        state._fixed.users[user].vault = vault;
        return vault;
    }

    function depositBorrowTokenToVariablePool(State storage state, address from, address to, uint256 amount) external {
        IERC20Metadata borrowAsset = IERC20Metadata(state._general.borrowAsset);

        borrowAsset.safeTransferFrom(from, address(this), amount);

        Vault vaultTo = getVault(state, to);

        borrowAsset.forceApprove(address(state._general.variablePool), amount);
        state._general.variablePool.supply(address(borrowAsset), amount, address(vaultTo), 0);
    }

    function withdrawBorrowTokenFromVariablePool(State storage state, address from, address to, uint256 amount)
        external
    {
        IERC20Metadata borrowAsset = IERC20Metadata(state._general.borrowAsset);

        Vault vaultFrom = getVault(state, from);

        // slither-disable-next-line unused-return
        vaultFrom.proxy(
            address(state._general.variablePool), abi.encodeCall(IPool.withdraw, (address(borrowAsset), amount, to))
        );
    }

    function transferBorrowAToken(State storage state, address from, address to, uint256 amount) public {
        IAToken borrowAToken = state._fixed.borrowAToken;

        Vault vaultFrom = getVault(state, from);
        Vault vaultTo = getVault(state, to);

        // slither-disable-next-line unused-return
        vaultFrom.proxy(address(borrowAToken), abi.encodeCall(IERC20.transfer, (address(vaultTo), amount)));
    }

    function _borrowFromVariablePool(
        State storage state,
        address from,
        address to,
        uint256 collateralAmount,
        uint256 borrowAmount
    ) internal {
        IERC20Metadata collateralAsset = IERC20Metadata(state._general.collateralAsset);
        IERC20Metadata borrowAsset = IERC20Metadata(state._general.borrowAsset);

        Vault vaultFrom = getVault(state, from);
        Vault vaultTo = getVault(state, to);

        // unwrap collateralToken (e.g. szETH) to collateralAsset (e.g. WETH) from `from` to `address(this)`
        state.withdrawCollateralToken(from, address(this), collateralAmount);

        // supply collateral asset
        state._general.collateralAsset.forceApprove(address(state._general.variablePool), collateralAmount);
        state._general.variablePool.supply(address(collateralAsset), collateralAmount, address(vaultFrom), 0);

        address[] memory targets = new address[](3);
        bytes[] memory data = new bytes[](3);

        // set collateralAsset as collateral
        targets[0] = address(state._general.variablePool);
        data[0] = abi.encodeCall(IPool.setUserUseReserveAsCollateral, (address(collateralAsset), true));

        // borrow
        targets[1] = address(state._general.variablePool);
        data[1] = abi.encodeCall(IPool.borrow, (address(borrowAsset), borrowAmount, 2, 0, address(vaultFrom)));

        // transfer to `address(this)`
        targets[2] = address(state._general.borrowAsset);
        data[2] = abi.encodeCall(IERC20.transfer, (address(this), borrowAmount));

        // slither-disable-next-line unused-return
        vaultFrom.proxy(targets, data);

        // supply to `to`
        borrowAsset.forceApprove(address(state._general.variablePool), borrowAmount);
        state._general.variablePool.supply(address(borrowAsset), borrowAmount, address(vaultTo), 0);
    }

    function borrowATokenBalanceOf(State storage state, address account) external view returns (uint256) {
        Vault vault = state._fixed.users[account].vault;
        if (address(vault) == address(0)) {
            return 0;
        } else {
            return state._fixed.borrowAToken.balanceOf(address(vault));
        }
    }

    function borrowATokenLiquidityIndex(State storage state) public view returns (uint256) {
        return state._general.variablePool.getReserveNormalizedIncome(address(state._general.borrowAsset));
    }

    function moveFixedLoanToVariablePool(State storage state, FixedLoan storage fol)
        external
        returns (uint256 liquidatorProfitCollateralToken)
    {
        liquidatorProfitCollateralToken = state._variable.collateralOverdueTransferFee;
        // In moving the loan from the fixed term to the variable, we assign collateral once to the loan and it is fixed
        uint256 assignedCollateral = state.getFOLAssignedCollateral(fol);

        state._fixed.collateralToken.transferFrom(fol.generic.borrower, msg.sender, liquidatorProfitCollateralToken);
        _borrowFromVariablePool(
            state,
            fol.generic.borrower,
            address(this),
            assignedCollateral - liquidatorProfitCollateralToken,
            state.getDebt(fol)
        );
    }
}
