// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ArrayLibrary} from "@src/libraries/ArrayLibrary.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {OracleLibrary} from "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import {PoolAddress} from "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";

/// @title UniswapV3PriceFeed
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @dev UniswapV3 TWAPs can be manipulated and, as such, this price feed should not be the primary oracle. See https://blog.uniswap.org/uniswap-v3-oracles
contract UniswapV3PriceFeed is IPriceFeed {
    uint256 public immutable decimals;
    IERC20Metadata public immutable baseToken;
    IERC20Metadata public immutable quoteToken;
    IUniswapV3Factory public immutable uniswapV3Factory;
    uint32 public immutable twapWindow;

    uint24[] public feeTiers;

    constructor(
        uint256 _decimals,
        IERC20Metadata _baseToken,
        IERC20Metadata _quoteToken,
        IUniswapV3Factory _uniswapV3Factory,
        uint32 _twapWindow
    ) {
        if (
            address(_baseToken) == address(0) || address(_quoteToken) == address(0)
                || address(_uniswapV3Factory) == address(0)
        ) {
            revert Errors.NULL_ADDRESS();
        }
        if (address(_baseToken) == address(_quoteToken)) {
            revert Errors.INVALID_TOKEN(address(_quoteToken));
        }
        if (twapWindow == 0) {
            revert Errors.NULL_AMOUNT();
        }

        decimals = _decimals;
        uniswapV3Factory = _uniswapV3Factory;
        baseToken = _baseToken;
        quoteToken = _quoteToken;
        twapWindow = _twapWindow;

        // https://docs.uniswap.org/concepts/protocol/fees#pool-fees-tiers
        // https://github.com/Uniswap/v3-core/blob/v1.0.0/contracts/UniswapV3Factory.sol
        feeTiers.push(500);
        feeTiers.push(3000);
        feeTiers.push(10000);
    }

    /// @notice Add a fee tier that might have been included after the deployment of the UniswapV3Factory contract
    function addFeeTier(uint24 feeTier) external {
        if (uniswapV3Factory.feeAmountTickSpacing(feeTier) == 0) {
            revert Errors.INVALID_FEE_TIER();
        }

        for (uint256 i = 0; i < feeTiers.length; i++) {
            if (feeTiers[i] == feeTier) {
                revert Errors.INVALID_FEE_TIER();
            }
        }
        feeTiers.push(feeTier);
    }

    function getPrice() external view override returns (uint256) {
        address[] memory pools = _getQueryablePools();
        OracleLibrary.WeightedTickData[] memory tickData = new OracleLibrary.WeightedTickData[](pools.length);

        for (uint256 i = 0; i < pools.length; i++) {
            (tickData[i].tick, tickData[i].weight) = _getObservation(pools[i]);
        }

        uint128 baseAmount = uint128(10 ** baseToken.decimals());
        int24 weightedTick =
            tickData.length == 1 ? tickData[0].tick : OracleLibrary.getWeightedArithmeticMeanTick(tickData);
        return OracleLibrary.getQuoteAtTick(weightedTick, baseAmount, address(baseToken), address(quoteToken));
    }

    function _getAllPools() internal view returns (address[] memory pools) {
        pools = new address[](feeTiers.length);
        uint256 validPoolsCount = 0;
        for (uint256 i = 0; i < feeTiers.length; i++) {
            address pool = PoolAddress.computeAddress(
                address(uniswapV3Factory), PoolAddress.getPoolKey(address(baseToken), address(quoteToken), feeTiers[i])
            );
            if (pool.code.length != 0) {
                pools[validPoolsCount++] = pool;
            }
        }

        ArrayLibrary.downsize(pools, validPoolsCount);
    }

    function _getQueryablePools() internal view returns (address[] memory queryablePools) {
        address[] memory allPools = _getAllPools();

        queryablePools = new address[](allPools.length);
        uint256 queriablePoolsCount = 0;
        for (uint256 i; i < allPools.length; i++) {
            if (OracleLibrary.getOldestObservationSecondsAgo(allPools[i]) >= twapWindow) {
                queryablePools[queriablePoolsCount++] = allPools[i];
            }
        }

        ArrayLibrary.downsize(queryablePools, queriablePoolsCount);
    }

    function _getObservation(address pool)
        internal
        view
        returns (int24 arithmeticMeanTick, uint128 harmonicMeanLiquidity)
    {
        uint32[] memory secondsAgo = new uint32[](2);
        secondsAgo[0] = twapWindow;
        secondsAgo[1] = 0;

        (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) =
            IUniswapV3Pool(pool).observe(secondsAgo);

        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        uint160 secondsPerLiquidityCumulativesDelta =
            secondsPerLiquidityCumulativeX128s[1] - secondsPerLiquidityCumulativeX128s[0];

        arithmeticMeanTick = int24(tickCumulativesDelta / int56(int32(twapWindow)));
        if (tickCumulativesDelta < 0 && (tickCumulativesDelta % int56(int32(twapWindow)) != 0)) arithmeticMeanTick--;

        uint192 secondsAgoX160 = uint192(twapWindow) * type(uint160).max;
        harmonicMeanLiquidity = uint128(secondsAgoX160 / (uint192(secondsPerLiquidityCumulativesDelta) << 32));
    }
}
