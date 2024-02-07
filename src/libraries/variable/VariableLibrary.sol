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

import {Loan, LoanLibrary} from "@src/libraries/fixed/LoanLibrary.sol";

import {Vault} from "@src/proxy/Vault.sol";

library VariableLibrary {
    using SafeERC20 for IERC20Metadata;
    using CollateralLibrary for State;
    using LoanLibrary for State;
    using LoanLibrary for Loan;

    function getVault(State storage state, address user) public returns (Vault) {
        if (address(state.data.users[user].vault) != address(0)) {
            return state.data.users[user].vault;
        }
        Vault vault = Vault(payable(Clones.clone(address(state.data.vaultImplementation))));
        emit Events.CreateVault(user, address(vault));
        vault.initialize(address(this));
        state.data.users[user].vault = vault;
        return vault;
    }

    function depositBorrowTokenToVariablePool(State storage state, address from, address to, uint256 amount) external {
        IERC20Metadata underlyingBorrowToken = IERC20Metadata(state.data.underlyingBorrowToken);

        underlyingBorrowToken.safeTransferFrom(from, address(this), amount);

        Vault vaultTo = getVault(state, to);

        underlyingBorrowToken.forceApprove(address(state.data.variablePool), amount);
        state.data.variablePool.supply(address(underlyingBorrowToken), amount, address(vaultTo), 0);
    }

    function withdrawBorrowTokenFromVariablePool(State storage state, address from, address to, uint256 amount)
        external
    {
        IERC20Metadata underlyingBorrowToken = IERC20Metadata(state.data.underlyingBorrowToken);

        Vault vaultFrom = getVault(state, from);

        // slither-disable-next-line unused-return
        vaultFrom.proxy(
            address(state.data.variablePool),
            abi.encodeCall(IPool.withdraw, (address(underlyingBorrowToken), amount, to))
        );
    }

    function transferBorrowAToken(State storage state, address from, address to, uint256 amount) public {
        IAToken borrowAToken = state.data.borrowAToken;

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
        IERC20Metadata underlyingCollateralToken = IERC20Metadata(state.data.underlyingCollateralToken);
        IERC20Metadata underlyingBorrowToken = IERC20Metadata(state.data.underlyingBorrowToken);

        Vault vaultFrom = getVault(state, from);
        Vault vaultTo = getVault(state, to);

        // unwrap collateralToken (e.g. szETH) to underlyingCollateralToken (e.g. WETH) from `from` to `address(this)`
        state.withdrawCollateralToken(from, address(this), collateralAmount);

        // supply collateral asset
        state.data.underlyingCollateralToken.forceApprove(address(state.data.variablePool), collateralAmount);
        state.data.variablePool.supply(address(underlyingCollateralToken), collateralAmount, address(vaultFrom), 0);

        address[] memory targets = new address[](3);
        bytes[] memory data = new bytes[](3);

        // set underlyingCollateralToken as collateral
        targets[0] = address(state.data.variablePool);
        data[0] = abi.encodeCall(IPool.setUserUseReserveAsCollateral, (address(underlyingCollateralToken), true));

        // borrow
        targets[1] = address(state.data.variablePool);
        data[1] = abi.encodeCall(IPool.borrow, (address(underlyingBorrowToken), borrowAmount, 2, 0, address(vaultFrom)));

        // transfer to `address(this)`
        targets[2] = address(state.data.underlyingBorrowToken);
        data[2] = abi.encodeCall(IERC20.transfer, (address(this), borrowAmount));

        // slither-disable-next-line unused-return
        vaultFrom.proxy(targets, data);

        // supply to `to`
        underlyingBorrowToken.forceApprove(address(state.data.variablePool), borrowAmount);
        state.data.variablePool.supply(address(underlyingBorrowToken), borrowAmount, address(vaultTo), 0);
    }

    function borrowATokenBalanceOf(State storage state, address account) external view returns (uint256) {
        Vault vault = state.data.users[account].vault;
        if (address(vault) == address(0)) {
            return 0;
        } else {
            return state.data.borrowAToken.balanceOf(address(vault));
        }
    }

    function borrowATokenLiquidityIndex(State storage state) public view returns (uint256) {
        return state.data.variablePool.getReserveNormalizedIncome(address(state.data.underlyingBorrowToken));
    }

    function moveLoanToVariablePool(State storage state, Loan memory folCopy)
        external
        returns (uint256 liquidatorProfitCollateralToken)
    {
        uint256 assignedCollateral = state.getFOLAssignedCollateral(folCopy);

        liquidatorProfitCollateralToken = state.config.collateralOverdueTransferFee;
        state.data.collateralToken.transferFrom(folCopy.generic.borrower, msg.sender, liquidatorProfitCollateralToken);

        // In moving the loan from the fixed term to the variable, we assign collateral once to the loan and it is fixed

        _borrowFromVariablePool(
            state,
            folCopy.generic.borrower,
            address(this),
            assignedCollateral - liquidatorProfitCollateralToken,
            folCopy.faceValue()
        );
    }
}
