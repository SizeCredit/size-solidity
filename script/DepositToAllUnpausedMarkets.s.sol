// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Size} from "@src/market/Size.sol";

import {MulticallUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BaseScript} from "@script/BaseScript.sol";
import {Contract, Networks} from "@script/Networks.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {ISizeFactoryV1_7} from "@src/factory/interfaces/ISizeFactoryV1_7.sol";
import {ISizeFactoryV1_8} from "@src/factory/interfaces/ISizeFactoryV1_8.sol";

import {Authorization} from "@src/factory/libraries/Authorization.sol";
import {Action} from "@src/factory/libraries/Authorization.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {ISizeV1_7} from "@src/market/interfaces/v1.7/ISizeV1_7.sol";
import {DepositParams} from "@src/market/libraries/actions/Deposit.sol";
import {DepositOnBehalfOfParams} from "@src/market/libraries/actions/Deposit.sol";
import {console} from "forge-std/console.sol";

contract DepositToAllUnpausedMarketsScript is BaseScript, Networks {
    using SafeERC20 for IERC20Metadata;

    function run() external broadcast {
        ISizeFactory sizeFactory = ISizeFactory(contracts[block.chainid][Contract.SIZE_FACTORY]);
        ISize[] memory markets = sizeFactory.getMarkets();
        ISize[] memory unpausedMarkets = new ISize[](markets.length);
        IERC20Metadata underlyingBorrowToken = IERC20Metadata(markets[0].data().underlyingBorrowToken);
        uint256 amount = 10 ** underlyingBorrowToken.decimals();
        uint256 unpausedMarketsLength = 0;
        for (uint256 i = 0; i < markets.length; i++) {
            if (!PausableUpgradeable(address(markets[i])).paused()) {
                unpausedMarkets[unpausedMarketsLength] = markets[i];
                unpausedMarketsLength++;
            }
        }
        _unsafeSetLength(unpausedMarkets, unpausedMarketsLength);
        bytes[] memory datas = new bytes[](1 + unpausedMarketsLength + 1);
        datas[0] = abi.encodeCall(
            ISizeFactoryV1_7.setAuthorization, (address(sizeFactory), Authorization.getActionsBitmap(Action.DEPOSIT))
        );
        for (uint256 i = 0; i < unpausedMarketsLength; i++) {
            underlyingBorrowToken.forceApprove(address(unpausedMarkets[i]), amount);
            datas[i + 1] = abi.encodeCall(
                ISizeFactoryV1_8.callMarket,
                (
                    unpausedMarkets[i],
                    abi.encodeCall(
                        ISizeV1_7.depositOnBehalfOf,
                        (
                            DepositOnBehalfOfParams({
                                params: DepositParams({
                                    token: address(underlyingBorrowToken),
                                    amount: amount,
                                    to: address(unpausedMarkets[i])
                                }),
                                onBehalfOf: msg.sender
                            })
                        )
                    )
                )
            );
        }
        datas[unpausedMarketsLength + 1] =
            abi.encodeCall(ISizeFactoryV1_7.setAuthorization, (address(sizeFactory), Authorization.nullActionsBitmap()));
        MulticallUpgradeable(address(sizeFactory)).multicall(datas);
    }
}
