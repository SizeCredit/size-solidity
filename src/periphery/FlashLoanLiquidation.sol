// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/core/interfaces/ISize.sol";

import {FlashLoanReceiverBase} from "@aave/flashloan/base/FlashLoanReceiverBase.sol";
import {IPool} from "@aave/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/interfaces/IPoolAddressesProvider.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Errors} from "@src/core/libraries/Errors.sol";
import {LiquidateParams} from "@src/core/libraries/fixed/actions/Liquidate.sol";
import {LiquidateWithReplacementParams} from "@src/core/libraries/fixed/actions/LiquidateWithReplacement.sol";
import {DepositParams} from "@src/core/libraries/general/actions/Deposit.sol";
import {WithdrawParams} from "@src/core/libraries/general/actions/Withdraw.sol";
import {DexSwap, SwapParams} from "@src/periphery/DexSwap.sol";

import {PeripheryErrors} from "@src/periphery/libraries/PeripheryErrors.sol";

struct ReplacementParams {
    uint256 minAPR;
    uint256 deadline;
    address replacementBorrower;
}

struct OperationParams {
    uint256 debtPositionId;
    uint256 minimumCollateralProfit;
    address recipient;
    SwapParams swapParams;
    bool depositProfits;
    bool useReplacement;
    ReplacementParams replacementParams;
    uint256 debtAmount;
}

/// @title FlashLoanLiquidator
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice A contract that liquidates debt positions using flash loans
contract FlashLoanLiquidator is Ownable, FlashLoanReceiverBase, DexSwap {
    using SafeERC20 for IERC20;

    ISize public immutable size;

    constructor(
        address _addressProvider,
        address _size,
        address _1inchAggregator,
        address _unoswapRouter,
        address _uniswapRouter,
        address _collateralToken,
        address _borrowToken
    )
        Ownable(msg.sender)
        FlashLoanReceiverBase(IPoolAddressesProvider(_addressProvider))
        DexSwap(_1inchAggregator, _unoswapRouter, _uniswapRouter, _collateralToken, _borrowToken)
    {
        if (_size == address(0) || _addressProvider == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        POOL = IPool(IPoolAddressesProvider(_addressProvider).getPool());
        size = ISize(_size);
    }

    function _liquidateDebtPositionWithReplacement(
        uint256 debtAmount,
        uint256 debtPositionId,
        uint256 minimumCollateralProfit,
        ReplacementParams memory replacementParams
    ) internal {
        // Approve USDC to repay the borrower's debt
        IERC20(borrowToken).forceApprove(address(size), debtAmount);

        // Encode Deposit
        bytes memory depositCall = abi.encodeWithSelector(
            ISize.deposit.selector, DepositParams({token: borrowToken, amount: debtAmount, to: address(this)})
        );

        // Encode Liquidate with Replacement
        bytes memory liquidateCall = abi.encodeWithSelector(
            ISize.liquidateWithReplacement.selector,
            LiquidateWithReplacementParams({
                debtPositionId: debtPositionId,
                borrower: replacementParams.replacementBorrower,
                minimumCollateralProfit: minimumCollateralProfit,
                deadline: replacementParams.deadline,
                minAPR: replacementParams.minAPR
            })
        );

        // Encode Withdraw
        bytes memory withdrawCall = abi.encodeWithSelector(
            ISize.withdraw.selector,
            WithdrawParams({token: collateralToken, amount: type(uint256).max, to: address(this)})
        );

        // Multicall
        bytes[] memory calls = new bytes[](3);
        calls[0] = depositCall;
        calls[1] = liquidateCall;
        calls[2] = withdrawCall;

        // slither-disable-next-line unused-return
        size.multicall(calls);
    }

    function _liquidateDebtPosition(uint256 debtAmount, uint256 debtPositionId, uint256 minimumCollateralProfit)
        internal
    {
        // Approve USDC to repay the borrower's debt
        IERC20(borrowToken).forceApprove(address(size), debtAmount);

        // Encode Deposit
        bytes memory depositCall = abi.encodeWithSelector(
            ISize.deposit.selector, DepositParams({token: borrowToken, amount: debtAmount, to: address(this)})
        );

        // Encode Liquidate
        bytes memory liquidateCall = abi.encodeWithSelector(
            ISize.liquidate.selector,
            LiquidateParams({debtPositionId: debtPositionId, minimumCollateralProfit: minimumCollateralProfit})
        );

        // Encode Withdraw
        bytes memory withdrawCall = abi.encodeWithSelector(
            ISize.withdraw.selector,
            WithdrawParams({token: collateralToken, amount: type(uint256).max, to: address(this)})
        );

        // Multicall
        bytes[] memory calls = new bytes[](3);
        calls[0] = depositCall;
        calls[1] = liquidateCall;
        calls[2] = withdrawCall;

        // slither-disable-next-line unused-return
        size.multicall(calls);
    }

    function _settleFlashLoan(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address recipient,
        bool depositProfits
    ) internal {
        uint256 totalDebt = amounts[0] + premiums[0];
        uint256 balance = IERC20(assets[0]).balanceOf(address(this));

        if (balance < totalDebt) {
            revert PeripheryErrors.INSUFFICIENT_BALANCE();
        }

        // Send remainder back to liquidator
        uint256 amountToLiquidator = balance - totalDebt;
        if (depositProfits) {
            IERC20(assets[0]).forceApprove(address(size), amountToLiquidator);
            size.deposit(DepositParams({token: assets[0], amount: amountToLiquidator, to: recipient}));
        } else {
            IERC20(assets[0]).transfer(recipient, amountToLiquidator);
        }

        // Approve the Pool contract to pull the owed amount
        IERC20(assets[0]).forceApprove(address(POOL), amounts[0] + premiums[0]);
    }

    function liquidatePositionWithFlashLoan(
        bool useReplacement,
        ReplacementParams memory replacementParams,
        uint256 debtPositionId,
        uint256 minimumCollateralProfit,
        SwapParams memory swapParams,
        uint256 supplementAmount,
        address recipient
    ) external {
        if (supplementAmount > 0) {
            IERC20(borrowToken).transferFrom(msg.sender, address(this), supplementAmount);
        }
        uint256 debtAmount = size.getDebtPosition(debtPositionId).futureValue;

        bool depositProfits = recipient != address(0);
        OperationParams memory opParams = OperationParams({
            debtPositionId: debtPositionId,
            minimumCollateralProfit: minimumCollateralProfit,
            recipient: depositProfits ? recipient : msg.sender,
            depositProfits: depositProfits,
            swapParams: swapParams,
            useReplacement: msg.sender == owner() ? useReplacement : false,
            replacementParams: replacementParams,
            debtAmount: debtAmount
        });

        bytes memory params = abi.encode(opParams);

        address[] memory assets = new address[](1);
        assets[0] = borrowToken;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = debtAmount - supplementAmount;
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        POOL.flashLoan(address(this), assets, amounts, modes, address(this), params, 0);
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        if (msg.sender != address(POOL)) {
            revert PeripheryErrors.NOT_AAVE_POOL();
        }
        if (initiator != address(this)) {
            revert PeripheryErrors.NOT_INITIATOR();
        }

        OperationParams memory opParams = abi.decode(params, (OperationParams));
        if (opParams.useReplacement) {
            _liquidateDebtPositionWithReplacement(
                opParams.debtAmount,
                opParams.debtPositionId,
                opParams.minimumCollateralProfit,
                opParams.replacementParams
            );
        } else {
            _liquidateDebtPosition(opParams.debtAmount, opParams.debtPositionId, opParams.minimumCollateralProfit);
        }

        _swapCollateral(opParams.swapParams);
        _settleFlashLoan(assets, amounts, premiums, opParams.recipient, opParams.depositProfits);

        return true;
    }

    function recover(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
    }
}
