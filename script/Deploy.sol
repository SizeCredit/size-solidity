// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {DataView} from "@src/market/SizeViewData.sol";

import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {MockERC4626} from "@solady/test/utils/mocks/MockERC4626.sol";

import "@crytic/properties/contracts/util/Hevm.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MockERC20} from "@solady/test/utils/mocks/MockERC20.sol";
import {Math} from "@src/market/libraries/Math.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

import {PriceFeed, PriceFeedParams} from "@src/oracle/v1.5.1/PriceFeed.sol";

import {PriceFeedMock} from "@test/mocks/PriceFeedMock.sol";

import {Size} from "@src/market/Size.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";

import {DEFAULT_VAULT} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
import {AaveAdapter} from "@src/market/token/adapters/AaveAdapter.sol";
import {ERC4626Adapter} from "@src/market/token/adapters/ERC4626Adapter.sol";

import {NetworkConfiguration} from "@script/Networks.sol";
import {
    Initialize,
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/market/libraries/actions/Initialize.sol";

import {SizeMock} from "@test/mocks/SizeMock.sol";
import {USDC} from "@test/mocks/USDC.sol";
import {WETH} from "@test/mocks/WETH.sol";

import {SizeFactory} from "@src/factory/SizeFactory.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {ERC4626} from "@solady/src/tokens/ERC4626.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {ControlledAsyncDeposit} from "@ERC-7540-Reference/src/ControlledAsyncDeposit.sol";
import {ControlledAsyncRedeem} from "@ERC-7540-Reference/src/ControlledAsyncRedeem.sol";
import {FullyAsyncVault} from "@ERC-7540-Reference/src/FullyAsyncVault.sol";

import {FeeOnEntryExitERC4626} from "@test/mocks/vaults/FeeOnEntryExitERC4626.sol";
import {FeeOnTransferERC4626} from "@test/mocks/vaults/FeeOnTransferERC4626.sol";
import {LimitsERC4626} from "@test/mocks/vaults/LimitsERC4626.sol";
import {MaliciousERC4626} from "@test/mocks/vaults/MaliciousERC4626.sol";

import {CollectionsManager} from "@src/collections/CollectionsManager.sol";

abstract contract Deploy {
    address internal implementation;
    ERC1967Proxy internal proxy;
    SizeMock internal size;
    IPriceFeed internal priceFeed;
    WETH internal weth;
    USDC internal usdc;
    IPool internal variablePool;
    InitializeFeeConfigParams internal f;
    InitializeRiskConfigParams internal r;
    InitializeOracleParams internal o;
    InitializeDataParams internal d;

    IERC20Metadata internal collateralToken;
    IERC20Metadata internal borrowToken;

    SizeFactory internal sizeFactory;
    CollectionsManager internal collectionsManager;

    bool internal shouldDeploySizeFactory = true;

    IERC4626 internal vault;
    IERC4626 internal vault2;
    IERC4626 internal vaultMalicious;
    IERC4626 internal vaultFeeOnTransfer;
    IERC4626 internal vaultFeeOnEntryExit;
    IERC4626 internal vaultLimits;
    IERC4626 internal vaultNonERC4626;
    IERC4626 internal vaultERC7540FullyAsync;
    IERC4626 internal vaultERC7540ControlledAsyncDeposit;
    IERC4626 internal vaultERC7540ControlledAsyncRedeem;
    IERC4626 internal vaultInvalidUnderlying;

    SizeMock internal size1;
    SizeMock internal size2;
    PriceFeedMock internal priceFeed2;
    IERC20Metadata internal collateral2;

    uint256 public constant TIMELOCK = 24 hours;

    function setupLocal(address owner, address feeRecipient) internal {
        priceFeed = new PriceFeedMock(owner);
        weth = new WETH();
        usdc = new USDC(owner);
        variablePool = IPool(address(new PoolMock()));
        PoolMock(address(variablePool)).setLiquidityIndex(address(weth), WadRayMath.RAY);
        PoolMock(address(variablePool)).setLiquidityIndex(address(usdc), WadRayMath.RAY);

        if (shouldDeploySizeFactory) {
            sizeFactory = SizeFactory(
                address(new ERC1967Proxy(address(new SizeFactory()), abi.encodeCall(SizeFactory.initialize, (owner))))
            );

            collectionsManager = CollectionsManager(
                address(
                    new ERC1967Proxy(
                        address(new CollectionsManager()),
                        abi.encodeCall(CollectionsManager.initialize, ISizeFactory(address(sizeFactory)))
                    )
                )
            );
            hevm.prank(owner);
            sizeFactory.setCollectionsManager(collectionsManager);
        }

        address borrowTokenVaultImplementation = address(new NonTransferrableRebasingTokenVault());

        _deployVaults();

        hevm.prank(owner);
        sizeFactory.setNonTransferrableRebasingTokenVaultImplementation(borrowTokenVaultImplementation);

        hevm.prank(owner);
        NonTransferrableRebasingTokenVault borrowTokenVault = sizeFactory.createBorrowTokenVault(variablePool, usdc);

        AaveAdapter aaveAdapter = new AaveAdapter(borrowTokenVault, variablePool, usdc);
        hevm.prank(owner);
        borrowTokenVault.setAdapter(bytes32("AaveAdapter"), aaveAdapter);
        hevm.prank(owner);
        borrowTokenVault.setVaultAdapter(DEFAULT_VAULT, bytes32("AaveAdapter"));

        ERC4626Adapter erc4626Adapter = new ERC4626Adapter(borrowTokenVault, usdc);
        hevm.prank(owner);
        borrowTokenVault.setAdapter(bytes32("ERC4626Adapter"), erc4626Adapter);

        f = InitializeFeeConfigParams({
            swapFeeAPR: 0.005e18,
            fragmentationFee: 5e6,
            liquidationRewardPercent: 0.05e18,
            overdueCollateralProtocolPercent: 0.01e18,
            collateralProtocolPercent: 0.1e18,
            feeRecipient: feeRecipient
        });
        r = InitializeRiskConfigParams({
            crOpening: 1.5e18,
            crLiquidation: 1.3e18,
            minimumCreditBorrowToken: 5e6,
            minTenor: 1 hours,
            maxTenor: 5 * 365 days
        });
        o = InitializeOracleParams({priceFeed: address(priceFeed), variablePoolBorrowRateStaleRateInterval: 0});
        d = InitializeDataParams({
            weth: address(weth),
            underlyingCollateralToken: address(weth),
            underlyingBorrowToken: address(usdc),
            variablePool: address(variablePool), // Aave v3
            borrowTokenVault: address(borrowTokenVault),
            sizeFactory: address(sizeFactory)
        });

        implementation = address(new SizeMock());
        hevm.prank(owner);
        sizeFactory.setSizeImplementation(implementation);

        hevm.prank(owner);
        proxy = ERC1967Proxy(payable(address(sizeFactory.createMarket(f, r, o, d))));
        size = SizeMock(payable(proxy));

        hevm.prank(owner);
        PriceFeedMock(address(priceFeed)).setPrice(1337e18);
    }

    function setupLocalGenericMarket(
        address owner,
        address feeRecipient,
        uint256 collateralTokenPriceUSD,
        uint256 borrowTokenPriceUSD,
        uint8 collateralTokenDecimals,
        uint8 borrowTokenDecimals,
        bool collateralTokenIsWETH,
        bool borrowTokenIsWETH
    ) internal {
        priceFeed = new PriceFeedMock(owner);
        uint256 price = Math.mulDivDown(collateralTokenPriceUSD, 10 ** priceFeed.decimals(), borrowTokenPriceUSD);

        weth = new WETH();
        collateralToken = IERC20Metadata(address(new MockERC20("CollateralToken", "CTK", collateralTokenDecimals)));
        borrowToken = IERC20Metadata(address(new MockERC20("BorrowToken", "BTK", borrowTokenDecimals)));
        if (collateralTokenIsWETH) {
            collateralToken = IERC20Metadata(address(weth));
        }
        if (borrowTokenIsWETH) {
            borrowToken = IERC20Metadata(address(weth));
        }

        variablePool = IPool(address(new PoolMock()));
        PoolMock(address(variablePool)).setLiquidityIndex(address(borrowToken), 1.234567e27);

        if (shouldDeploySizeFactory) {
            sizeFactory = SizeFactory(
                address(new ERC1967Proxy(address(new SizeFactory()), abi.encodeCall(SizeFactory.initialize, (owner))))
            );

            collectionsManager = CollectionsManager(
                address(
                    new ERC1967Proxy(
                        address(new CollectionsManager()),
                        abi.encodeCall(CollectionsManager.initialize, ISizeFactory(address(sizeFactory)))
                    )
                )
            );
            hevm.prank(owner);
            sizeFactory.setCollectionsManager(collectionsManager);
        }

        address borrowTokenVaultImplementation = address(new NonTransferrableRebasingTokenVault());

        vault = IERC4626(address(new MockERC4626(address(borrowToken), "Vault", "VAULT", true, 0)));

        hevm.prank(owner);
        sizeFactory.setNonTransferrableRebasingTokenVaultImplementation(borrowTokenVaultImplementation);

        hevm.prank(owner);
        NonTransferrableRebasingTokenVault borrowTokenVault =
            sizeFactory.createBorrowTokenVault(variablePool, borrowToken);

        AaveAdapter aaveAdapter = new AaveAdapter(borrowTokenVault, variablePool, borrowToken);
        hevm.prank(owner);
        borrowTokenVault.setAdapter(bytes32("AaveAdapter"), aaveAdapter);
        hevm.prank(owner);
        borrowTokenVault.setVaultAdapter(DEFAULT_VAULT, bytes32("AaveAdapter"));

        ERC4626Adapter erc4626Adapter = new ERC4626Adapter(borrowTokenVault, borrowToken);
        hevm.prank(owner);
        borrowTokenVault.setAdapter(bytes32("ERC4626Adapter"), erc4626Adapter);

        f = InitializeFeeConfigParams({
            swapFeeAPR: 0.005e18,
            fragmentationFee: Math.mulDivDown(
                5 * 10 ** borrowToken.decimals(), 10 ** priceFeed.decimals(), borrowTokenPriceUSD
            ),
            liquidationRewardPercent: 0.05e18,
            overdueCollateralProtocolPercent: 0.01e18,
            collateralProtocolPercent: 0.1e18,
            feeRecipient: feeRecipient
        });
        r = InitializeRiskConfigParams({
            crOpening: 1.5e18,
            crLiquidation: 1.3e18,
            minimumCreditBorrowToken: Math.mulDivDown(
                10 * 10 ** borrowToken.decimals(), 10 ** priceFeed.decimals(), borrowTokenPriceUSD
            ),
            minTenor: 1 hours,
            maxTenor: 5 * 365 days
        });
        o = InitializeOracleParams({priceFeed: address(priceFeed), variablePoolBorrowRateStaleRateInterval: 0});
        d = InitializeDataParams({
            weth: address(weth),
            underlyingCollateralToken: address(collateralToken),
            underlyingBorrowToken: address(borrowToken),
            variablePool: address(variablePool),
            borrowTokenVault: address(borrowTokenVault),
            sizeFactory: address(sizeFactory)
        });

        implementation = address(new SizeMock());
        hevm.prank(owner);
        sizeFactory.setSizeImplementation(implementation);

        hevm.prank(owner);
        proxy = ERC1967Proxy(payable(address(sizeFactory.createMarket(f, r, o, d))));
        size = SizeMock(payable(proxy));

        hevm.prank(owner);
        PriceFeedMock(address(priceFeed)).setPrice(price);
    }

    function setupFork(address _size, address _priceFeed, address _variablePool, address _weth, address _usdc)
        internal
    {
        size = SizeMock(_size);
        priceFeed = IPriceFeed(_priceFeed);
        variablePool = IPool(_variablePool);
        weth = WETH(payable(_weth));
        usdc = USDC(_usdc);
    }

    function _deployVaults() internal {
        vault = IERC4626(address(new MockERC4626(address(usdc), "Vault", "VAULT", true, 0)));
        vault2 = IERC4626(address(new ERC4626Mock(address(usdc))));
        vaultMalicious = IERC4626(address(new MaliciousERC4626(usdc, "VaultMalicious", "VAULTMALICIOUS")));
        vaultFeeOnTransfer =
            IERC4626(address(new FeeOnTransferERC4626(usdc, "VaultFeeOnTransfer", "VAULTFEEONTXFER", 0.1e18)));
        vaultFeeOnEntryExit = IERC4626(
            address(new FeeOnEntryExitERC4626(usdc, "VaultFeeOnEntryExit", "VAULTFEEONENTRYEXIT", 0.1e4, 0.2e4))
        );
        vaultLimits =
            IERC4626(address(new LimitsERC4626(usdc, "VaultLimits", "VAULTLIMITS", 1000e6, 2000e6, 3000e6, 4000e6)));
        vaultNonERC4626 = IERC4626(address(new ERC20Mock()));
        vaultERC7540FullyAsync =
            IERC4626(address(new FullyAsyncVault(ERC20(address(usdc)), "VaultERC7540", "VAULTERC7540")));
        vaultERC7540ControlledAsyncDeposit =
            IERC4626(address(new ControlledAsyncDeposit(ERC20(address(usdc)), "VaultERC7540", "VAULTERC7540")));
        vaultERC7540ControlledAsyncRedeem =
            IERC4626(address(new ControlledAsyncRedeem(ERC20(address(usdc)), "VaultERC7540", "VAULTERC7540")));
        vaultInvalidUnderlying = IERC4626(
            address(new MockERC4626(address(weth), "VaultInvalidUnderlying", "VAULTINVALIDUNDERLYING", true, 0))
        );
    }

    function _deploySizeMarket2() internal {
        collateral2 = IERC20Metadata(address(new ERC20Mock()));
        priceFeed2 = new PriceFeedMock(address(this));
        priceFeed2.setPrice(1e18);

        ISize market = sizeFactory.getMarket(0);
        InitializeFeeConfigParams memory feeConfigParams = market.feeConfig();

        InitializeRiskConfigParams memory riskConfigParams = market.riskConfig();
        riskConfigParams.crOpening = 1.12e18;
        riskConfigParams.crLiquidation = 1.09e18;

        InitializeOracleParams memory oracleParams = market.oracle();
        oracleParams.priceFeed = address(priceFeed2);

        DataView memory dataView = market.data();
        InitializeDataParams memory dataParams = InitializeDataParams({
            weth: address(weth),
            underlyingCollateralToken: address(collateral2),
            underlyingBorrowToken: address(dataView.underlyingBorrowToken),
            variablePool: address(dataView.variablePool),
            borrowTokenVault: address(dataView.borrowTokenVault),
            sizeFactory: address(sizeFactory)
        });
        size2 = SizeMock(address(sizeFactory.createMarket(feeConfigParams, riskConfigParams, oracleParams, dataParams)));
        size1 = size;

        hevm.label(address(size1), "Size1");
        hevm.label(address(size2), "Size2");
    }
}
