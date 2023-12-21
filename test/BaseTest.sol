// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {AssertsHelper} from "./helpers/AssertsHelper.sol";
import {PriceFeedMock} from "./mocks/PriceFeedMock.sol";

import {USDC} from "./mocks/USDC.sol";
import {WETH} from "./mocks/WETH.sol";
import {Size} from "@src/Size.sol";
import {User, UserView} from "@src/libraries/UserLibrary.sol";
import {YieldCurve, YieldCurveLibrary} from "@src/libraries/YieldCurveLibrary.sol";
import {InitializeExtraParams, InitializeParams} from "@src/libraries/actions/Initialize.sol";
import {BorrowToken} from "@src/token/BorrowToken.sol";

import {BorrowToken} from "@src/token/BorrowToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";
import {DebtToken} from "@src/token/DebtToken.sol";

import {DebtToken} from "@src/token/DebtToken.sol";

import {BorrowAsLimitOrderParams} from "@src/libraries/actions/BorrowAsLimitOrder.sol";
import {BorrowAsMarketOrderParams} from "@src/libraries/actions/BorrowAsMarketOrder.sol";

import {BorrowerExitParams} from "@src/libraries/actions/BorrowerExit.sol";
import {ClaimParams} from "@src/libraries/actions/Claim.sol";
import {DepositParams} from "@src/libraries/actions/Deposit.sol";
import {LendAsLimitOrderParams} from "@src/libraries/actions/LendAsLimitOrder.sol";
import {LendAsMarketOrderParams} from "@src/libraries/actions/LendAsMarketOrder.sol";
import {LiquidateLoanParams} from "@src/libraries/actions/LiquidateLoan.sol";
import {MoveToVariablePoolParams} from "@src/libraries/actions/MoveToVariablePool.sol";

import {LiquidateLoanWithReplacementParams} from "@src/libraries/actions/LiquidateLoanWithReplacement.sol";
import {RepayParams} from "@src/libraries/actions/Repay.sol";
import {SelfLiquidateLoanParams} from "@src/libraries/actions/SelfLiquidateLoan.sol";
import {WithdrawParams} from "@src/libraries/actions/Withdraw.sol";

contract BaseTest is Test, AssertsHelper {
    event TODO();

    Size public size;
    PriceFeedMock public priceFeed;
    WETH public weth;
    USDC public usdc;
    CollateralToken public collateralToken;
    BorrowToken public borrowToken;
    DebtToken public debtToken;

    address public alice = address(0x10000);
    address public bob = address(0x20000);
    address public candy = address(0x30000);
    address public james = address(0x40000);
    address public liquidator = address(0x50000);
    address public protocolVault = address(0x60000);
    address public feeRecipient = address(0x70000);

    struct Vars {
        UserView alice;
        UserView bob;
        UserView candy;
        UserView james;
        UserView liquidator;
        uint256 protocolCollateralAmount;
        uint256 protocolBorrowAmount;
        uint256 feeRecipientCollateralAmount;
        uint256 feeRecipientBorrowAmount;
    }

    function setUp() public virtual {
        priceFeed = new PriceFeedMock(address(this));
        weth = new WETH();
        usdc = new USDC();
        collateralToken = new CollateralToken(address(this), "Size ETH", "szETH");
        borrowToken = new BorrowToken(address(this), "Size USDC", "szUSDC");
        debtToken = new DebtToken(address(this), "Size Debt Token", "szDebt");
        InitializeParams memory params = InitializeParams({
            owner: address(this),
            priceFeed: address(priceFeed),
            collateralAsset: address(weth),
            borrowAsset: address(usdc),
            collateralToken: address(collateralToken),
            borrowToken: address(borrowToken),
            debtToken: address(debtToken),
            protocolVault: protocolVault,
            feeRecipient: feeRecipient
        });

        InitializeExtraParams memory extraParams = InitializeExtraParams({
            crOpening: 1.5e18,
            crLiquidation: 1.3e18,
            collateralPercentagePremiumToLiquidator: 0.3e18,
            collateralPercentagePremiumToBorrower: 0.1e18,
            minimumFaceValue: 5e18
        });
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(new Size()), abi.encodeCall(Size.initialize, (params, extraParams)));
        size = Size(address(proxy));

        collateralToken.transferOwnership(address(size));
        borrowToken.transferOwnership(address(size));
        debtToken.transferOwnership(address(size));

        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(candy, "candy");
        vm.label(james, "james");
        vm.label(liquidator, "liquidator");

        priceFeed.setPrice(1337e18);
    }

    function _deposit(address user, IERC20Metadata token, uint256 amount) internal {
        _deposit(user, address(token), amount);
    }

    function _deposit(address user, address token, uint256 amount) internal {
        deal(token, user, amount);
        vm.prank(user);
        IERC20Metadata(token).approve(address(size), amount);
        vm.prank(user);
        size.deposit(DepositParams({token: token, amount: amount}));
    }

    function _withdraw(address user, IERC20Metadata token, uint256 amount) internal {
        _withdraw(user, address(token), amount);
    }

    function _withdraw(address user, address token, uint256 amount) internal {
        vm.prank(user);
        size.withdraw(WithdrawParams({token: token, amount: amount}));
    }

    function _deposit(address user, uint256 collateralAssetValue, uint256 debtAssetValue) internal {
        _deposit(user, weth, collateralAssetValue);
        _deposit(user, usdc, debtAssetValue);
    }

    function _lendAsLimitOrder(
        address lender,
        uint256 maxAmount,
        uint256 maxDueDate,
        uint256[2] memory ratesArray,
        uint256[2] memory timeBucketsArray
    ) internal {
        uint256[] memory rates = new uint256[](2);
        uint256[] memory timeBuckets = new uint256[](2);
        rates[0] = ratesArray[0];
        rates[1] = ratesArray[1];
        timeBuckets[0] = timeBucketsArray[0];
        timeBuckets[1] = timeBucketsArray[1];
        YieldCurve memory curveRelativeTime = YieldCurve({timeBuckets: timeBuckets, rates: rates});
        return _lendAsLimitOrder(lender, maxAmount, maxDueDate, curveRelativeTime);
    }

    function _lendAsLimitOrder(
        address lender,
        uint256 maxAmount,
        uint256 maxDueDate,
        uint256 rate,
        uint256 timeBucketsLength
    ) internal {
        YieldCurve memory curveRelativeTime = YieldCurveLibrary.getFlatRate(timeBucketsLength, rate);
        return _lendAsLimitOrder(lender, maxAmount, maxDueDate, curveRelativeTime);
    }

    function _lendAsLimitOrder(
        address lender,
        uint256 maxAmount,
        uint256 maxDueDate,
        YieldCurve memory curveRelativeTime
    ) internal {
        vm.prank(lender);
        size.lendAsLimitOrder(
            LendAsLimitOrderParams({maxAmount: maxAmount, maxDueDate: maxDueDate, curveRelativeTime: curveRelativeTime})
        );
    }

    function _borrowAsMarketOrder(address borrower, address lender, uint256 amount, uint256 dueDate)
        internal
        returns (uint256)
    {
        uint256[] memory virtualCollateralLoanIds;
        return _borrowAsMarketOrder(borrower, lender, amount, dueDate, false, virtualCollateralLoanIds);
    }

    function _borrowAsMarketOrder(
        address borrower,
        address lender,
        uint256 amount,
        uint256 dueDate,
        uint256[1] memory ids
    ) internal returns (uint256) {
        uint256[] memory virtualCollateralLoanIds = new uint256[](1);
        virtualCollateralLoanIds[0] = ids[0];
        return _borrowAsMarketOrder(borrower, lender, amount, dueDate, false, virtualCollateralLoanIds);
    }

    function _borrowAsMarketOrder(
        address borrower,
        address lender,
        uint256 amount,
        uint256 dueDate,
        uint256[] memory virtualCollateralLoanIds
    ) internal returns (uint256) {
        return _borrowAsMarketOrder(borrower, lender, amount, dueDate, false, virtualCollateralLoanIds);
    }

    function _borrowAsMarketOrder(
        address borrower,
        address lender,
        uint256 amount,
        uint256 dueDate,
        bool exactAmountIn,
        uint256[1] memory ids
    ) internal returns (uint256) {
        uint256[] memory virtualCollateralLoanIds = new uint256[](1);
        virtualCollateralLoanIds[0] = ids[0];
        return _borrowAsMarketOrder(borrower, lender, amount, dueDate, exactAmountIn, virtualCollateralLoanIds);
    }

    function _borrowAsMarketOrder(
        address borrower,
        address lender,
        uint256 amount,
        uint256 dueDate,
        bool exactAmountIn,
        uint256[] memory virtualCollateralLoanIds
    ) internal returns (uint256) {
        vm.prank(borrower);
        size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: lender,
                amount: amount,
                dueDate: dueDate,
                exactAmountIn: exactAmountIn,
                virtualCollateralLoanIds: virtualCollateralLoanIds
            })
        );
        return size.activeLoans() - 1;
    }

    function _borrowAsLimitOrder(
        address borrower,
        uint256 maxAmount,
        uint256[] memory timeBuckets,
        uint256[] memory rates
    ) internal {
        YieldCurve memory curveRelativeTime = YieldCurve({timeBuckets: timeBuckets, rates: rates});
        vm.prank(borrower);
        size.borrowAsLimitOrder(BorrowAsLimitOrderParams({maxAmount: maxAmount, curveRelativeTime: curveRelativeTime}));
    }

    function _borrowAsLimitOrder(address borrower, uint256 maxAmount, uint256 rate, uint256 timeBucketsLength)
        internal
    {
        YieldCurve memory curveRelativeTime = YieldCurveLibrary.getFlatRate(timeBucketsLength, rate);
        vm.prank(borrower);
        size.borrowAsLimitOrder(BorrowAsLimitOrderParams({maxAmount: maxAmount, curveRelativeTime: curveRelativeTime}));
    }

    function _lendAsMarketOrder(address lender, address borrower, uint256 amount, uint256 dueDate)
        internal
        returns (uint256)
    {
        return _lendAsMarketOrder(lender, borrower, amount, dueDate, false);
    }

    function _lendAsMarketOrder(address lender, address borrower, uint256 amount, uint256 dueDate, bool exactAmountIn)
        internal
        returns (uint256)
    {
        vm.prank(lender);
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({borrower: borrower, amount: amount, dueDate: dueDate, exactAmountIn: exactAmountIn})
        );
        return size.activeLoans() - 1;
    }

    function _borrowerExit(address user, uint256 loanId, address borrowerToExitTo) internal {
        vm.prank(user);
        size.borrowerExit(BorrowerExitParams({loanId: loanId, borrowerToExitTo: borrowerToExitTo}));
    }

    function _repay(address user, uint256 loanId) internal {
        vm.prank(user);
        size.repay(RepayParams({loanId: loanId}));
    }

    function _claim(address user, uint256 loanId) internal {
        vm.prank(user);
        size.claim(ClaimParams({loanId: loanId}));
    }

    function _liquidateLoan(address user, uint256 loanId) internal returns (uint256) {
        vm.prank(user);
        return size.liquidateLoan(LiquidateLoanParams({loanId: loanId}));
    }

    function _selfLiquidateLoan(address user, uint256 loanId) internal {
        vm.prank(user);
        return size.selfLiquidateLoan(SelfLiquidateLoanParams({loanId: loanId}));
    }

    function _liquidateLoanWithReplacement(address user, uint256 loanId, address borrower) internal returns (uint256) {
        vm.prank(user);
        return
            size.liquidateLoanWithReplacement(LiquidateLoanWithReplacementParams({loanId: loanId, borrower: borrower}));
    }

    function _moveToVariablePool(address user, uint256 loanId) internal {
        vm.prank(user);
        size.moveToVariablePool(MoveToVariablePoolParams({loanId: loanId}));
    }

    function _state() internal view returns (Vars memory vars) {
        vars.alice = size.getUserView(alice);
        vars.bob = size.getUserView(bob);
        vars.candy = size.getUserView(candy);
        vars.james = size.getUserView(james);
        vars.liquidator = size.getUserView(liquidator);
        vars.protocolCollateralAmount = collateralToken.balanceOf(protocolVault);
        vars.protocolBorrowAmount = borrowToken.balanceOf(protocolVault);
        vars.feeRecipientCollateralAmount = collateralToken.balanceOf(feeRecipient);
        vars.feeRecipientBorrowAmount = borrowToken.balanceOf(feeRecipient);
    }

    function _setPrice(uint256 price) internal {
        vm.prank(address(this));
        priceFeed.setPrice(price);
    }
}
