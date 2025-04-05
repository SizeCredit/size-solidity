// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Safe} from "@safe-utils/Safe.sol";
import {BaseScript} from "@script/BaseScript.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {Tenderly} from "@tenderly-utils/Tenderly.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {KEEPER_ROLE} from "@src/factory/interfaces/ISizeFactory.sol";

import {console} from "forge-std/console.sol";

contract ProposeSafeTxUpdateKeeperRoleAllMarketsScript is BaseScript {
    using Tenderly for *;
    using Safe for *;

    address sender;
    Tenderly.Client tenderly;
    Safe.Client safe;

    ISizeFactory private sizeFactory;
    address private liquidator;
    address private safeAddress;

    modifier parseEnv() {
        sender = vm.envAddress("SENDER");

        sizeFactory = ISizeFactory(vm.envAddress("SIZE_FACTORY"));

        string memory accountSlug = vm.envString("TENDERLY_ACCOUNT_NAME");
        string memory projectSlug = vm.envString("TENDERLY_PROJECT_NAME");
        string memory accessKey = vm.envString("TENDERLY_ACCESS_KEY");

        tenderly.initialize(accountSlug, projectSlug, accessKey);

        safeAddress = vm.envAddress("SAFE_ADDRESS");
        safe.initialize(safeAddress);

        liquidator = vm.envAddress("LIQUIDATOR");

        _;
    }

    function run() external parseEnv ignoreGas {
        bytes memory data = abi.encodeCall(AccessControl.grantRole, (KEEPER_ROLE, liquidator));
        address to = address(sizeFactory);
        safe.proposeTransaction(to, data, sender);
        Tenderly.VirtualTestnet memory vnet =
            tenderly.createVirtualTestnet("ProposeSafeTxUpdateKeeperRoleAllMarkets", 1_000_000 + block.chainid);
        bytes memory execTransactionData = safe.getExecTransactionData(to, data);
        tenderly.sendTransaction(vnet.id, safeAddress, to, execTransactionData);
    }
}
