// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {MulticallUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {console} from "forge-std/console.sol";

import {SizeFactory} from "@src/factory/SizeFactory.sol";
import {Size} from "@src/market/Size.sol";
import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";

import {BaseScript} from "@script/BaseScript.sol";
import {Contract, Networks} from "@script/Networks.sol";

import {Safe} from "@safe-utils/Safe.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {Tenderly} from "@tenderly-utils/Tenderly.sol";

contract ProposeSafeTxUpgradeToV1_8Script is BaseScript, Networks {
    using Tenderly for *;
    using Safe for *;

    address signer;
    string derivationPath;

    ISizeFactory private sizeFactory;
    address private safeAddress;

    modifier parseEnv() {
        signer = vm.envAddress("SIGNER");
        derivationPath = vm.envString("LEDGER_PATH");
        sizeFactory = ISizeFactory(contracts[block.chainid][Contract.SIZE_FACTORY]);

        string memory accountSlug = vm.envString("TENDERLY_ACCOUNT_NAME");
        string memory projectSlug = vm.envString("TENDERLY_PROJECT_NAME");
        string memory accessKey = vm.envString("TENDERLY_ACCESS_KEY");

        tenderly.initialize(accountSlug, projectSlug, accessKey);

        safeAddress = vm.envAddress("OWNER");
        safe.initialize(safeAddress);

        _;
    }

    function run() external parseEnv {
        // TODO untested
        vm.startBroadcast();

        Size sizeV1_8 = new Size();
        SizeFactory sizeFactoryV1_8 = new SizeFactory();
        NonTransferrableRebasingTokenVault borrowTokenVaultV1_8 = new NonTransferrableRebasingTokenVault();

        vm.stopBroadcast();

        ISize[] memory markets = sizeFactory.getMarkets();

        address[] memory targets = new address[](markets.length + 2);
        bytes[] memory datas = new bytes[](markets.length + 2);

        // Size.upgradeToAndCall(v1_8, 0x) for all markets
        for (uint256 i = 0; i < markets.length; i++) {
            targets[i] = address(markets[i]);
            datas[i] = abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(sizeV1_8), bytes("")));
        }

        // NonTransferrableScaledTokenV1_5.upgradeToAndCall(v1_8, reinitialize(name, symbol))
        targets[markets.length] = address(borrowTokenVaultV1_8);
        datas[markets.length] = abi.encodeCall(
            UUPSUpgradeable.upgradeToAndCall,
            (
                address(borrowTokenVaultV1_8),
                abi.encodeCall(NonTransferrableRebasingTokenVault.reinitialize, ("Size USD Coin Vault", "svUSDC"))
            )
        );

        // SizeFactory.upgradeToAndCall(v1_8, multicall[setSizeImplementation,setNonTransferrableRebasingTokenVaultImplementation])
        bytes[] memory multicallDatas = new bytes[](2);
        multicallDatas[0] = abi.encodeCall(SizeFactory.setSizeImplementation, (address(sizeV1_8)));
        multicallDatas[1] = abi.encodeCall(
            SizeFactory.setNonTransferrableRebasingTokenVaultImplementation, (address(borrowTokenVaultV1_8))
        );

        targets[markets.length + 1] = address(sizeFactory);
        datas[markets.length + 1] = abi.encodeCall(
            UUPSUpgradeable.upgradeToAndCall,
            (address(sizeFactoryV1_8), abi.encodeCall(MulticallUpgradeable.multicall, (multicallDatas)))
        );

        safe.proposeTransactions(targets, datas, signer, derivationPath);

        Tenderly.VirtualTestnet[] memory vnets = tenderly.getVirtualTestnets();
        for (uint256 i = 0; i < vnets.length; i++) {
            tenderly.deleteVirtualTestnetById(vnets[i].id);
        }

        Tenderly.VirtualTestnet memory vnet = tenderly.createVirtualTestnet("upgrade-to-v1_8", block.chainid);
        tenderly.setStorageAt(vnet, safe.instance().safe, Safe.SAFE_THRESHOLD_STORAGE_SLOT, bytes32(uint256(1)));
        tenderly.sendTransaction(
            vnet.id, signer, safe.instance().safe, safe.getExecTransactionsData(targets, datas, signer, derivationPath)
        );
    }
}
