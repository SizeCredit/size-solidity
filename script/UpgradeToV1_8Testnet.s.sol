// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {MulticallUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {console} from "forge-std/console.sol";

import {NonTransferrableScaledTokenV1_5} from "@deprecated/token/NonTransferrableScaledTokenV1_5.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {CollectionsManager} from "@src/collections/CollectionsManager.sol";
import {SizeFactory} from "@src/factory/SizeFactory.sol";
import {Size} from "@src/market/Size.sol";
import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";

import {BaseScript} from "@script/BaseScript.sol";
import {Contract, Networks} from "@script/Networks.sol";

import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {Tenderly} from "@tenderly-utils/Tenderly.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {AaveAdapter} from "@src/market/token/adapters/AaveAdapter.sol";
import {ERC4626Adapter} from "@src/market/token/adapters/ERC4626Adapter.sol";

import {IPool} from "@aave/interfaces/IPool.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ISizeV1_8} from "@src/market/interfaces/v1.8/ISizeV1_8.sol";

contract UpgradeToV1_8TestnetScript is BaseScript, Networks {
    ISizeFactory sizeFactory;
    address owner;

    address[] users;
    address curator;
    address rateProvider;
    ISize[] collectionMarkets;

    modifier parseEnv() {
        sizeFactory = ISizeFactory(contracts[block.chainid][Contract.SIZE_FACTORY]);

        owner = vm.envAddress("OWNER");

        users = vm.envAddress("USERS", ",");
        curator = vm.envOr("CURATOR", address(0));
        rateProvider = vm.envOr("RATE_PROVIDER", address(0));

        console.log("users", users.length);
        console.log("curator", curator);
        console.log("rateProvider", rateProvider);
        console.log("collectionMarkets", collectionMarkets.length);

        _;
    }

    function getTargetsAndDatas(
        ISizeFactory _sizeFactory,
        address[] memory _users,
        address _curator,
        address _rateProvider,
        ISize[] memory _collectionMarkets
    ) public returns (address[] memory targets, bytes[] memory datas) {
        ISize[] memory markets = _sizeFactory.getMarkets();
        NonTransferrableScaledTokenV1_5 v1_5saToken =
            NonTransferrableScaledTokenV1_5(address(markets[0].data().borrowTokenVault));

        /* deployments start */
        Size sizeV1_8Implementation = new Size();
        SizeFactory sizeFactoryV1_8Implementation = new SizeFactory();
        NonTransferrableRebasingTokenVault borrowTokenVaultV1_8Implementation = new NonTransferrableRebasingTokenVault();
        CollectionsManager collectionsManager = CollectionsManager(
            address(
                new ERC1967Proxy(
                    address(new CollectionsManager()),
                    abi.encodeCall(CollectionsManager.initialize, ISizeFactory(address(_sizeFactory)))
                )
            )
        );
        AaveAdapter aaveAdapter = new AaveAdapter(
            NonTransferrableRebasingTokenVault(address(v1_5saToken)),
            v1_5saToken.variablePool(),
            v1_5saToken.underlyingToken()
        );
        ERC4626Adapter erc4626Adapter =
            new ERC4626Adapter(NonTransferrableRebasingTokenVault(address(v1_5saToken)), v1_5saToken.underlyingToken());
        /* deployment end */

        targets = new address[](markets.length + 2);
        datas = new bytes[](markets.length + 2);

        // Size.upgradeToAndCall(v1_8, reinitialize) for all markets
        for (uint256 i = 0; i < markets.length; i++) {
            targets[i] = address(markets[i]);
            datas[i] = abi.encodeCall(
                UUPSUpgradeable.upgradeToAndCall,
                (address(sizeV1_8Implementation), abi.encodeCall(ISizeV1_8.reinitialize, ()))
            );
        }

        // NonTransferrableScaledTokenV1_5.upgradeToAndCall(v1_8, reinitialize(name, symbol))
        targets[markets.length] = address(v1_5saToken);
        datas[markets.length] = abi.encodeCall(
            UUPSUpgradeable.upgradeToAndCall,
            (
                address(borrowTokenVaultV1_8Implementation),
                abi.encodeCall(
                    NonTransferrableRebasingTokenVault.reinitialize,
                    ("Size USD Coin Vault", "svUSDC", aaveAdapter, erc4626Adapter)
                )
            )
        );

        // SizeFactory.upgradeToAndCall(v1_8, multicall[reinitialize, setSizeImplementation, setNonTransferrableRebasingTokenVaultImplementation])
        bytes[] memory multicallDatas = new bytes[](3);
        multicallDatas[0] = abi.encodeCall(
            SizeFactory.reinitialize, (collectionsManager, _users, _curator, _rateProvider, _collectionMarkets)
        );
        multicallDatas[1] = abi.encodeCall(SizeFactory.setSizeImplementation, (address(sizeV1_8Implementation)));
        multicallDatas[2] = abi.encodeCall(
            SizeFactory.setNonTransferrableRebasingTokenVaultImplementation,
            (address(borrowTokenVaultV1_8Implementation))
        );

        targets[markets.length + 1] = address(_sizeFactory);
        datas[markets.length + 1] = abi.encodeCall(
            UUPSUpgradeable.upgradeToAndCall,
            (address(sizeFactoryV1_8Implementation), abi.encodeCall(MulticallUpgradeable.multicall, (multicallDatas)))
        );
    }

    function run() external parseEnv broadcast {
        (address[] memory targets, bytes[] memory datas) =
            getTargetsAndDatas(sizeFactory, users, curator, rateProvider, collectionMarkets);

        for (uint256 i = 0; i < targets.length; i++) {
            (bool success,) = targets[i].call(datas[i]);
            require(success, "Upgrade failed");
        }
    }
}
