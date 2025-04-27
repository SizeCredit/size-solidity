// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AssertsHelper} from "@test/helpers/AssertsHelper.sol";

import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {UNISWAP_V3_FACTORY_BYTECODE} from "@test/mocks/UniswapV3FactoryBytecode.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Size} from "@src/market/Size.sol";
import {YieldCurve} from "@src/market/libraries/YieldCurveLibrary.sol";

import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {DepositParams} from "@src/market/libraries/actions/Deposit.sol";
import {WithdrawParams} from "@src/market/libraries/actions/Withdraw.sol";

import {SellCreditLimitParams} from "@src/market/libraries/actions/SellCreditLimit.sol";
import {
    SellCreditMarketOnBehalfOfParams,
    SellCreditMarketParams
} from "@src/market/libraries/actions/SellCreditMarket.sol";

import {DEBT_POSITION_ID_START, RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";

import {BuyCreditLimitParams} from "@src/market/libraries/actions/BuyCreditLimit.sol";
import {ClaimParams} from "@src/market/libraries/actions/Claim.sol";
import {LiquidateParams} from "@src/market/libraries/actions/Liquidate.sol";

import {CompensateParams} from "@src/market/libraries/actions/Compensate.sol";

import {LiquidateWithReplacementParams} from "@src/market/libraries/actions/LiquidateWithReplacement.sol";
import {PartialRepayParams} from "@src/market/libraries/actions/PartialRepay.sol";
import {RepayParams} from "@src/market/libraries/actions/Repay.sol";
import {SelfLiquidateParams} from "@src/market/libraries/actions/SelfLiquidate.sol";

import {BuyCreditMarketParams} from "@src/market/libraries/actions/BuyCreditMarket.sol";
import {SetUserConfigurationParams} from "@src/market/libraries/actions/SetUserConfiguration.sol";

import {KEEPER_ROLE} from "@src/factory/SizeFactory.sol";
import {UserView} from "@src/market/SizeView.sol";
import {CopyLimitOrder} from "@src/market/libraries/OfferLibrary.sol";
import {CopyLimitOrdersParams} from "@src/market/libraries/actions/CopyLimitOrders.sol";

import {UpdateConfigParams} from "@src/market/libraries/actions/UpdateConfig.sol";

import {PoolMock} from "@test/mocks/PoolMock.sol";
import {PriceFeedMock} from "@test/mocks/PriceFeedMock.sol";

import {ActionsBitmap} from "@src/factory/libraries/Authorization.sol";

import {Deploy} from "@script/Deploy.sol";

struct Vars {
    UserView alice;
    UserView bob;
    UserView candy;
    UserView james;
    UserView liquidator;
    UserView variablePool;
    UserView size;
    UserView feeRecipient;
}

contract BaseTest is Test, Deploy, AssertsHelper {
    address internal alice = address(0x10000);
    address internal bob = address(0x20000);
    address internal candy = address(0x30000);
    address internal james = address(0x40000);
    address internal liquidator = address(0x50000);
    address internal feeRecipient = address(0x70000);

    function setUp() public virtual {
        setupLocal(address(this), feeRecipient);
        _labels();
    }

    function _labels() internal {
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(candy, "candy");
        vm.label(james, "james");
        vm.label(liquidator, "liquidator");
        vm.label(feeRecipient, "feeRecipient");

        vm.label(address(proxy), "Size-proxy");
        vm.label(address(implementation), "Size-implementation");
        vm.label(address(size), "Size");
        vm.label(address(priceFeed), "PriceFeed");
        vm.label(address(usdc), "USDC");
        vm.label(address(weth), "WETH");
        vm.label(address(variablePool), "VariablePool");

        vm.label(address(size.data().collateralToken), "szWETH");
        vm.label(address(size.data().borrowTokenVault), "szvUSDC");
        vm.label(address(size.data().debtToken), "szDebtUSDC");

        vm.label(address(sizeFactory), "SizeFactory");

        vm.label(address(0), "address(0)");
        vm.label(address(this), "Test");
    }

    function _mint(address token, address user, uint256 amount) internal {
        deal(token, user, amount);
    }

    function _approve(address user, address token, address spender, uint256 amount) internal {
        vm.prank(user);
        IERC20Metadata(token).approve(spender, amount);
    }

    function _state() internal view returns (Vars memory vars) {
        vars.alice = size.getUserView(alice);
        vars.bob = size.getUserView(bob);
        vars.candy = size.getUserView(candy);
        vars.james = size.getUserView(james);
        vars.liquidator = size.getUserView(liquidator);
        vars.variablePool = size.getUserView(address(variablePool));
        vars.size = size.getUserView(address(size));
        vars.feeRecipient = size.getUserView(feeRecipient);
    }

    function _setPrice(uint256 price) internal {
        vm.prank(address(this));
        PriceFeedMock(address(priceFeed)).setPrice(price);
    }

    function _setVariablePoolBorrowRate(uint128 rate) internal {
        vm.prank(address(this));
        size.setVariablePoolBorrowRate(rate);
    }

    function _updateConfig(string memory key, uint256 value) internal {
        vm.prank(address(this));
        size.updateConfig(UpdateConfigParams({key: key, value: value}));
    }

    function _setKeeperRole(address user) internal {
        vm.prank(address(this));
        size.grantRole(KEEPER_ROLE, user);
    }

    function _deposit(address user, IERC20Metadata token, uint256 amount) internal {
        _deposit(user, address(token), amount, user);
    }

    function _deposit(address user, address token, uint256 amount) internal {
        _deposit(user, token, amount, user);
    }

    function _deposit(address user, address token, uint256 amount, address to) internal {
        _mint(token, user, amount);
        _approve(user, token, address(size), amount);
        vm.prank(user);
        size.deposit(DepositParams({token: token, amount: amount, to: to}));
    }

    function _withdraw(address user, IERC20Metadata token, uint256 amount) internal {
        _withdraw(user, address(token), amount, user);
    }

    function _withdraw(address user, address token, uint256 amount) internal {
        _withdraw(user, token, amount, user);
    }

    function _withdraw(address user, address token, uint256 amount, address to) internal {
        vm.prank(user);
        size.withdraw(WithdrawParams({token: token, amount: amount, to: to}));
    }

    function _buyCreditLimit(
        address lender,
        uint256 maxDueDate,
        int256[1] memory ratesArray,
        uint256[1] memory tenorsArray
    ) internal {
        int256[] memory aprs = new int256[](1);
        uint256[] memory tenors = new uint256[](1);
        uint256[] memory marketRateMultipliers = new uint256[](1);
        aprs[0] = ratesArray[0];
        tenors[0] = tenorsArray[0];
        YieldCurve memory curveRelativeTime =
            YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: aprs});
        return _buyCreditLimit(lender, maxDueDate, curveRelativeTime);
    }

    function _buyCreditLimit(
        address lender,
        uint256 maxDueDate,
        int256[2] memory ratesArray,
        uint256[2] memory tenorsArray
    ) internal {
        int256[] memory aprs = new int256[](2);
        uint256[] memory tenors = new uint256[](2);
        uint256[] memory marketRateMultipliers = new uint256[](2);
        aprs[0] = ratesArray[0];
        aprs[1] = ratesArray[1];
        tenors[0] = tenorsArray[0];
        tenors[1] = tenorsArray[1];
        YieldCurve memory curveRelativeTime =
            YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: aprs});
        return _buyCreditLimit(lender, maxDueDate, curveRelativeTime);
    }

    function _buyCreditLimit(address lender, uint256 maxDueDate, YieldCurve memory curveRelativeTime) internal {
        vm.prank(lender);
        size.buyCreditLimit(BuyCreditLimitParams({maxDueDate: maxDueDate, curveRelativeTime: curveRelativeTime}));
    }

    function _sellCreditMarket(
        address borrower,
        address lender,
        uint256 creditPositionId,
        uint256 amount,
        uint256 tenor,
        bool exactAmountIn
    ) internal returns (uint256) {
        vm.prank(borrower);
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: lender,
                creditPositionId: creditPositionId,
                amount: amount,
                tenor: tenor,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: exactAmountIn
            })
        );
        (uint256 debtPositionsCount,) = size.getPositionsCount();
        return DEBT_POSITION_ID_START + debtPositionsCount - 1;
    }

    function _sellCreditMarket(
        address borrower,
        address lender,
        uint256 creditPositionId,
        uint256 amount,
        uint256 tenor
    ) internal returns (uint256) {
        return _sellCreditMarket(borrower, lender, creditPositionId, amount, tenor, true);
    }

    function _sellCreditMarket(address borrower, address lender, uint256 creditPositionId) internal returns (uint256) {
        return _sellCreditMarket(
            borrower, lender, creditPositionId, size.getCreditPosition(creditPositionId).credit, type(uint256).max, true
        );
    }

    function _sellCreditMarket(address borrower, address lender, uint256 amount, uint256 tenor, bool exactAmountIn)
        internal
        returns (uint256)
    {
        return _sellCreditMarket(borrower, lender, RESERVED_ID, amount, tenor, exactAmountIn);
    }

    function _sellCreditLimit(address borrower, uint256 maxDueDate, YieldCurve memory curveRelativeTime) internal {
        vm.prank(borrower);
        size.sellCreditLimit(SellCreditLimitParams({maxDueDate: maxDueDate, curveRelativeTime: curveRelativeTime}));
    }

    function _sellCreditLimit(
        address borrower,
        uint256 maxDueDate,
        int256[1] memory ratesArray,
        uint256[1] memory tenorsArray
    ) internal {
        int256[] memory aprs = new int256[](1);
        uint256[] memory tenors = new uint256[](1);
        uint256[] memory marketRateMultipliers = new uint256[](1);
        aprs[0] = ratesArray[0];
        tenors[0] = tenorsArray[0];
        YieldCurve memory curveRelativeTime =
            YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: aprs});
        return _sellCreditLimit(borrower, maxDueDate, curveRelativeTime);
    }

    function _sellCreditLimit(
        address borrower,
        uint256 maxDueDate,
        int256[2] memory ratesArray,
        uint256[2] memory tenorsArray
    ) internal {
        int256[] memory aprs = new int256[](2);
        uint256[] memory tenors = new uint256[](2);
        uint256[] memory marketRateMultipliers = new uint256[](2);
        aprs[0] = ratesArray[0];
        aprs[1] = ratesArray[1];
        tenors[0] = tenorsArray[0];
        tenors[1] = tenorsArray[1];
        YieldCurve memory curveRelativeTime =
            YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: aprs});
        return _sellCreditLimit(borrower, maxDueDate, curveRelativeTime);
    }

    function _sellCreditLimit(address borrower, uint256 maxDueDate, int256 rate, uint256 tenor) internal {
        YieldCurve memory curveRelativeTime = YieldCurveHelper.pointCurve(tenor, rate);
        return _sellCreditLimit(borrower, maxDueDate, curveRelativeTime);
    }

    function _buyCreditMarket(address lender, uint256 creditPositionId, uint256 amount, bool exactAmountIn)
        internal
        returns (uint256)
    {
        return _buyCreditMarket(lender, address(0), creditPositionId, amount, type(uint256).max, exactAmountIn);
    }

    function _buyCreditMarket(address lender, address borrower, uint256 amount, uint256 tenor)
        internal
        returns (uint256)
    {
        return _buyCreditMarket(lender, borrower, RESERVED_ID, amount, tenor, false);
    }

    function _buyCreditMarket(address lender, address borrower, uint256 amount, uint256 tenor, bool exactAmountIn)
        internal
        returns (uint256)
    {
        return _buyCreditMarket(lender, borrower, RESERVED_ID, amount, tenor, exactAmountIn);
    }

    function _buyCreditMarket(
        address user,
        address borrower,
        uint256 creditPositionId,
        uint256 amount,
        uint256 tenor,
        bool exactAmountIn
    ) internal returns (uint256) {
        vm.prank(user);
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: borrower,
                creditPositionId: creditPositionId,
                tenor: tenor,
                amount: amount,
                exactAmountIn: exactAmountIn,
                deadline: block.timestamp,
                minAPR: 0
            })
        );

        (uint256 debtPositionsCount,) = size.getPositionsCount();
        return DEBT_POSITION_ID_START + debtPositionsCount - 1;
    }

    function _repay(address user, uint256 debtPositionId, address borrower) internal {
        vm.prank(user);
        size.repay(RepayParams({debtPositionId: debtPositionId, borrower: borrower}));
    }

    function _partialRepay(address user, uint256 creditPositionWithDebtToRepayId, uint256 amount, address borrower)
        internal
    {
        vm.prank(user);
        size.partialRepay(
            PartialRepayParams({
                creditPositionWithDebtToRepayId: creditPositionWithDebtToRepayId,
                amount: amount,
                borrower: borrower
            })
        );
    }

    function _claim(address user, uint256 creditPositionId) internal {
        vm.prank(user);
        size.claim(ClaimParams({creditPositionId: creditPositionId}));
    }

    function _liquidate(address user, uint256 debtPositionId) internal returns (uint256) {
        return _liquidate(user, debtPositionId, 0, type(uint256).max);
    }

    function _liquidate(address user, uint256 debtPositionId, uint256 minimumCollateralProfit, uint256 deadline)
        internal
        returns (uint256)
    {
        vm.prank(user);
        return size.liquidate(
            LiquidateParams({
                debtPositionId: debtPositionId,
                minimumCollateralProfit: minimumCollateralProfit,
                deadline: deadline
            })
        );
    }

    function _selfLiquidate(address user, uint256 creditPositionId) internal {
        vm.prank(user);
        return size.selfLiquidate(SelfLiquidateParams({creditPositionId: creditPositionId}));
    }

    function _liquidateWithReplacement(address user, uint256 debtPositionId, address borrower)
        internal
        returns (uint256, uint256)
    {
        return _liquidateWithReplacement(user, debtPositionId, borrower, 1e18);
    }

    function _liquidateWithReplacement(
        address user,
        uint256 debtPositionId,
        address borrower,
        uint256 minimumCollateralProfit
    ) internal returns (uint256, uint256) {
        vm.prank(user);
        return size.liquidateWithReplacement(
            LiquidateWithReplacementParams({
                debtPositionId: debtPositionId,
                borrower: borrower,
                minimumCollateralProfit: minimumCollateralProfit,
                deadline: block.timestamp,
                minAPR: 0
            })
        );
    }

    function _compensate(address user, uint256 creditPositionWithDebtToRepayId, uint256 creditPositionToCompensateId)
        internal
    {
        return _compensate(user, creditPositionWithDebtToRepayId, creditPositionToCompensateId, type(uint256).max);
    }

    function _compensate(
        address user,
        uint256 creditPositionWithDebtToRepayId,
        uint256 creditPositionToCompensateId,
        uint256 amount
    ) internal {
        vm.prank(user);
        size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: creditPositionWithDebtToRepayId,
                creditPositionToCompensateId: creditPositionToCompensateId,
                amount: amount
            })
        );
    }

    function _setUserConfiguration(
        address user,
        address vault,
        uint256 openingLimitBorrowCR,
        bool allCreditPositionsForSaleDisabled,
        bool creditPositionIdsForSale,
        uint256[] memory creditPositionIds
    ) internal {
        vm.prank(user);
        size.setUserConfiguration(
            SetUserConfigurationParams({
                vault: vault,
                openingLimitBorrowCR: openingLimitBorrowCR,
                allCreditPositionsForSaleDisabled: allCreditPositionsForSaleDisabled,
                creditPositionIdsForSale: creditPositionIdsForSale,
                creditPositionIds: creditPositionIds
            })
        );
    }

    function _copyLimitOrders(
        address user,
        address copyAddress,
        CopyLimitOrder memory copyLoanOffer,
        CopyLimitOrder memory copyBorrowOffer
    ) internal {
        vm.prank(user);
        size.copyLimitOrders(
            CopyLimitOrdersParams({
                copyAddress: copyAddress,
                copyLoanOffer: copyLoanOffer,
                copyBorrowOffer: copyBorrowOffer
            })
        );
    }

    function _setAuthorization(address user, address operator, ActionsBitmap actionsBitmap) internal {
        vm.prank(user);
        sizeFactory.setAuthorization(operator, actionsBitmap);
    }

    function _setLiquidityIndex(address token, uint256 index) internal {
        vm.prank(address(this));
        PoolMock(address(variablePool)).setLiquidityIndex(token, index);
    }

    function _setVaultWhitelisted(IERC4626 v, bool whitelisted) internal {
        return _setVaultWhitelisted(address(v), whitelisted);
    }

    function _setVaultWhitelisted(address v, bool whitelisted) internal {
        NonTransferrableRebasingTokenVault borrowTokenVault =
            NonTransferrableRebasingTokenVault(address(size.data().borrowTokenVault));
        vm.prank(address(this));
        borrowTokenVault.setVaultWhitelisted(v, whitelisted);
    }

    function _setLiquidityIndex(uint256 index) internal {
        _setLiquidityIndex(address(usdc), index);
    }

    function _deployUniswapV3Factory() internal returns (IUniswapV3Factory) {
        bytes memory bytecode = UNISWAP_V3_FACTORY_BYTECODE;
        address deployed;
        assembly {
            deployed := create(0, add(bytecode, 0x20), mload(bytecode))
            if iszero(deployed) { revert(0, 0) }
        }
        vm.label(deployed, "IUniswapV3Factory");
        return IUniswapV3Factory(deployed);
    }

    function _isUserUnderwater(address user) internal view returns (bool) {
        return size.collateralRatio(user) < size.riskConfig().crLiquidation;
    }
}
