// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {BaseScript} from "@script/BaseScript.sol";
import {CollectionsManager} from "@src/collections/CollectionsManager.sol";
import {ICollectionsManager} from "@src/collections/interfaces/ICollectionsManager.sol";
import {SizeFactory} from "@src/factory/SizeFactory.sol";

import {Contract, Networks} from "@script/Networks.sol";
import {console} from "forge-std/console.sol";

import {Safe} from "@safe-utils/Safe.sol";

contract ProposeSafeTxUpgradeToV1_8_1Script is BaseScript, Networks {
    using Safe for *;

    address signer;
    string derivationPath;
    SizeFactory private sizeFactory;
    ICollectionsManager private collectionsManager;

    modifier parseEnv() {
        safe.initialize(vm.envAddress("OWNER"));
        signer = vm.envAddress("SIGNER");
        derivationPath = vm.envString("LEDGER_PATH");

        _;
    }

    function run() public parseEnv broadcast {
        console.log("ProposeSafeTxUpgradeToV1_8_1Script");

        (address[] memory targets, bytes[] memory datas) = getUpgradeToV1_8_1Data();

        safe.proposeTransactions(targets, datas, signer, derivationPath);

        console.log("ProposeSafeTxUpgradeToV1_8_1Script: done");
    }

    function getUpgradeToV1_8_1Data() public returns (address[] memory targets, bytes[] memory datas) {
        sizeFactory = SizeFactory(contracts[block.chainid][Contract.SIZE_FACTORY]);
        collectionsManager = sizeFactory.collectionsManager();

        CollectionsManager newCollectionsManagerImplementation = new CollectionsManager();
        console.log(
            "ProposeSafeTxUpgradeToV1_8_1Script: newCollectionsManagerImplementation",
            address(newCollectionsManagerImplementation)
        );
        SizeFactory newSizeFactoryImplementation = new SizeFactory();
        console.log(
            "ProposeSafeTxUpgradeToV1_8_1Script: newSizeFactoryImplementation", address(newSizeFactoryImplementation)
        );

        targets = new address[](2);
        datas = new bytes[](2);

        // Upgrade SizeFactory
        targets[0] = address(sizeFactory);
        datas[0] = abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(newSizeFactoryImplementation), ""));

        // Upgrade CollectionsManager
        targets[1] = address(collectionsManager);
        datas[1] = abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(newCollectionsManagerImplementation), ""));
    }
}
