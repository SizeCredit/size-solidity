// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {console2 as console} from "forge-std/Script.sol";

import {Size} from "@src/Size.sol";

import {BaseScript, Deployment, Parameter} from "@script/BaseScript.sol";
import {Deploy} from "@script/Deploy.sol";
import {NetworkParams, Networks} from "@script/Networks.sol";

contract DeployScript is BaseScript, Networks, Deploy {
    bool mockContracts;
    address deployer;
    address owner;
    address feeRecipient;
    address wethAggregator;
    address usdcAggregator;
    string chainName;

    function setUp() public {}

    modifier parseEnv() {
        deployer = vm.envOr("DEPLOYER_ADDRESS", vm.addr(vm.deriveKey(TEST_MNEMONIC, 0)));
        owner = vm.envOr("OWNER", address(0));
        feeRecipient = vm.envOr("FEE_RECIPIENT", address(0));
        chainName = vm.envOr("CHAIN_NAME", TEST_CHAIN_NAME);
        _;
    }

    function run() public parseEnv broadcast returns (Deployment[] memory, Parameter[] memory) {
        console.log("[Size v1] deploying...");

        console.log("[Size v1] chain:       ", chainName);
        console.log("[Size v1] deployer:    ", deployer);
        console.log("[Size v1] owner:       ", owner);
        console.log("[Size v1] feeRecipient:", feeRecipient);

        NetworkParams memory networkParams = params(chainName);

        setupProduction(owner, feeRecipient, networkParams);

        deployments.push(Deployment({name: "Size-implementation", addr: address(implementation)}));
        deployments.push(Deployment({name: "Size-proxy", addr: address(proxy)}));
        deployments.push(Deployment({name: "PriceFeed", addr: address(priceFeed)}));
        parameters.push(Parameter({key: "owner", value: Strings.toHexString(owner)}));
        parameters.push(Parameter({key: "feeRecipient", value: Strings.toHexString(feeRecipient)}));
        parameters.push(Parameter({key: "usdc", value: Strings.toHexString(address(networkParams.usdc))}));
        parameters.push(Parameter({key: "weth", value: Strings.toHexString(address(networkParams.weth))}));
        parameters.push(Parameter({key: "wethAggregator", value: Strings.toHexString(networkParams.wethAggregator)}));
        parameters.push(Parameter({key: "usdcAggregator", value: Strings.toHexString(networkParams.usdcAggregator)}));
        parameters.push(Parameter({key: "wethHeartbeat", value: Strings.toString(networkParams.wethHeartbeat)}));
        parameters.push(Parameter({key: "usdcHeartbeat", value: Strings.toString(networkParams.wethHeartbeat)}));
        parameters.push(
            Parameter({key: "sequencerUptimeFeed", value: Strings.toHexString(networkParams.sequencerUptimeFeed)})
        );
        parameters.push(Parameter({key: "variablePool", value: Strings.toHexString(address(variablePool))}));

        console.log("[Size v1] deployed\n");

        for (uint256 i = 0; i < deployments.length; i++) {
            console.log("[Size v1] Deployment: ", deployments[i].name, "\t", address(deployments[i].addr));
        }
        for (uint256 i = 0; i < parameters.length; i++) {
            console.log("[Size v1] Parameter:  ", parameters[i].key, "\t", parameters[i].value);
        }

        exportDeployments(chainName);

        console.log("[Size v1] done");

        return (deployments, parameters);
    }
}
