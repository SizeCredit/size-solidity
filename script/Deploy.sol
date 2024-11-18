// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";

import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";

import "@crytic/properties/contracts/util/Hevm.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {MockERC20} from "@solady/../test/utils/mocks/MockERC20.sol";
import {Math} from "@src/libraries/Math.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

import {PriceFeed} from "@src/oracle/PriceFeed.sol";

import {PriceFeedMock} from "@test/mocks/PriceFeedMock.sol";

import {Size} from "@src/Size.sol";
import {ISize} from "@src/interfaces/ISize.sol";

import {NetworkConfiguration} from "@script/Networks.sol";
import {
    Initialize,
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/libraries/actions/Initialize.sol";
import {SizeMock} from "@test/mocks/SizeMock.sol";
import {USDC} from "@test/mocks/USDC.sol";
import {WETH} from "@test/mocks/WETH.sol";

import {SizeFactory} from "@src/v1.5/SizeFactory.sol";
import {ISizeFactory} from "@src/v1.5/interfaces/ISizeFactory.sol";
import {NonTransferrableScaledTokenV1_5} from "@src/v1.5/token/NonTransferrableScaledTokenV1_5.sol";

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

    function setupLocal(address owner, address feeRecipient) internal {
        priceFeed = new PriceFeedMock(owner);
        weth = new WETH();
        usdc = new USDC(owner);
        variablePool = IPool(address(new PoolMock()));
        PoolMock(address(variablePool)).setLiquidityIndex(address(weth), WadRayMath.RAY);
        PoolMock(address(variablePool)).setLiquidityIndex(address(usdc), WadRayMath.RAY);

        _deployLocalSizeFactoryIfNeeded(owner);

        hevm.prank(owner);
        sizeFactory.createBorrowATokenV1_5(variablePool, usdc);

        NonTransferrableScaledTokenV1_5 borrowAToken =
            NonTransferrableScaledTokenV1_5(address(sizeFactory.getBorrowATokenV1_5(0)));

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
            minimumCreditBorrowAToken: 5e6,
            borrowATokenCap: 1_000_000e6,
            minTenor: 1 hours,
            maxTenor: 5 * 365 days
        });
        o = InitializeOracleParams({priceFeed: address(priceFeed), variablePoolBorrowRateStaleRateInterval: 0});
        d = InitializeDataParams({
            weth: address(weth),
            underlyingCollateralToken: address(weth),
            underlyingBorrowToken: address(usdc),
            variablePool: address(variablePool), // Aave v3
            borrowATokenV1_5: address(borrowAToken)
        });

        implementation = address(new SizeMock());
        proxy = new ERC1967Proxy(implementation, abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        size = SizeMock(payable(proxy));

        hevm.prank(owner);
        sizeFactory.addMarket(ISize(size));

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

        _deployLocalSizeFactoryIfNeeded(owner);

        NonTransferrableScaledTokenV1_5 borrowAToken =
            _deployBorrowAToken(owner, ISizeFactory(sizeFactory), variablePool, borrowToken);

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
            minimumCreditBorrowAToken: Math.mulDivDown(
                10 * 10 ** borrowToken.decimals(), 10 ** priceFeed.decimals(), borrowTokenPriceUSD
            ),
            borrowATokenCap: Math.mulDivDown(
                1_000_000 * 10 ** borrowToken.decimals(), 10 ** priceFeed.decimals(), borrowTokenPriceUSD
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
            borrowATokenV1_5: address(borrowAToken)
        });

        implementation = address(new SizeMock());
        proxy = new ERC1967Proxy(implementation, abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        size = SizeMock(payable(proxy));

        hevm.prank(owner);
        sizeFactory.addMarket(ISize(size));

        hevm.prank(owner);
        PriceFeedMock(address(priceFeed)).setPrice(price);
    }

    /// @notice Deploys the contracts needed for the production environment (legacy deployment)
    /// @dev The owner should add the contracts to the registry after this function is called
    function setupProduction(address _owner, address _feeRecipient, NetworkConfiguration memory _networkParams)
        internal
    {
        variablePool = IPool(_networkParams.variablePool);

        if (
            _networkParams.underlyingCollateralTokenAggregator == address(0)
                && _networkParams.underlyingBorrowTokenAggregator == address(0)
        ) {
            priceFeed = new PriceFeedMock(_owner);
        } else {
            priceFeed = new PriceFeed(
                _networkParams.underlyingCollateralTokenAggregator,
                _networkParams.underlyingBorrowTokenAggregator,
                _networkParams.sequencerUptimeFeed,
                _networkParams.underlyingCollateralTokenHeartbeat,
                _networkParams.underlyingBorrowTokenHeartbeat
            );
        }

        if (_networkParams.variablePool == address(0)) {
            variablePool = IPool(address(new PoolMock()));
            PoolMock(address(variablePool)).setLiquidityIndex(
                address(_networkParams.underlyingCollateralToken), WadRayMath.RAY
            );
            PoolMock(address(variablePool)).setLiquidityIndex(
                address(_networkParams.underlyingBorrowToken), WadRayMath.RAY
            );
        } else {
            variablePool = IPool(_networkParams.variablePool);
        }

        sizeFactory = _deploySizeFactory(_owner);

        NonTransferrableScaledTokenV1_5 borrowAToken = _deployBorrowAToken(
            _owner, ISizeFactory(sizeFactory), variablePool, IERC20Metadata(_networkParams.underlyingBorrowToken)
        );
        f = InitializeFeeConfigParams({
            swapFeeAPR: 0.005e18,
            fragmentationFee: _networkParams.fragmentationFee,
            liquidationRewardPercent: 0.05e18,
            overdueCollateralProtocolPercent: 0.01e18,
            collateralProtocolPercent: 0.1e18,
            feeRecipient: _feeRecipient
        });
        r = InitializeRiskConfigParams({
            crOpening: _networkParams.crOpening,
            crLiquidation: _networkParams.crLiquidation,
            minimumCreditBorrowAToken: _networkParams.minimumCreditBorrowAToken,
            borrowATokenCap: _networkParams.borrowATokenCap,
            minTenor: 1 hours,
            maxTenor: 5 * 365 days
        });
        o = InitializeOracleParams({priceFeed: address(priceFeed), variablePoolBorrowRateStaleRateInterval: 0});
        d = InitializeDataParams({
            weth: address(_networkParams.weth),
            underlyingCollateralToken: address(_networkParams.underlyingCollateralToken),
            underlyingBorrowToken: address(_networkParams.underlyingBorrowToken),
            variablePool: address(variablePool), // Aave v3
            borrowATokenV1_5: address(borrowAToken)
        });
        implementation = address(new Size());
        proxy = new ERC1967Proxy(implementation, abi.encodeCall(Size.initialize, (_owner, f, r, o, d)));
        size = SizeMock(payable(proxy));
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

    function _deploySizeFactory(address _owner) internal returns (SizeFactory _sizeFactory) {
        _sizeFactory = SizeFactory(
            address(new ERC1967Proxy(address(new SizeFactory()), abi.encodeCall(SizeFactory.initialize, (_owner))))
        );
    }

    function _deployLocalSizeFactoryIfNeeded(address _owner) internal {
        if (address(sizeFactory) != address(0)) {
            return;
        }
        sizeFactory = _deploySizeFactory(_owner);
    }

    function _deployBorrowAToken(
        address _owner,
        ISizeFactory _sizeFactory,
        IPool _variablePool,
        IERC20Metadata _underlyingBorrowToken
    ) internal returns (NonTransferrableScaledTokenV1_5 borrowAToken) {
        borrowAToken = NonTransferrableScaledTokenV1_5(
            address(
                new ERC1967Proxy(
                    address(new NonTransferrableScaledTokenV1_5()),
                    abi.encodeCall(
                        NonTransferrableScaledTokenV1_5.initialize,
                        (
                            _sizeFactory,
                            _variablePool,
                            _underlyingBorrowToken,
                            address(_owner),
                            string.concat("Size Scaled ", _underlyingBorrowToken.name(), " (v1.5)"),
                            string.concat("sza", _underlyingBorrowToken.symbol()),
                            _underlyingBorrowToken.decimals()
                        )
                    )
                )
            )
        );
    }
}
