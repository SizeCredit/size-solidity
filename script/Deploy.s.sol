// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {console2 as console} from "forge-std/Script.sol";

import {Size} from "@src/Size.sol";

import {BaseScript, Deployment, Parameter} from "@script/BaseScript.sol";
import {Deploy} from "@script/Deploy.sol";
import {NetworkConfiguration, Networks} from "@script/Networks.sol";

contract DeployScript is BaseScript, Networks, Deploy {
    bool mockContracts;
    address deployer;
    address owner;
    address feeRecipient;
    string networkConfiguration;

    function setUp() public {}

    modifier parseEnv() {
        deployer = vm.envOr("DEPLOYER_ADDRESS", vm.addr(vm.deriveKey(TEST_MNEMONIC, 0)));
        owner = vm.envOr("OWNER", address(0));
        feeRecipient = vm.envOr("FEE_RECIPIENT", address(0));
        networkConfiguration = vm.envOr("NETWORK_CONFIGURATION", TEST_NETWORK_CONFIGURATION);
        _;
    }

    function run() public parseEnv broadcast returns (Deployment[] memory, Parameter[] memory) {
        console.log("[Size v1] deploying...");

        console.log("[Size v1] networkConfiguration", networkConfiguration);
        console.log("[Size v1] deployer", deployer);
        console.log("[Size v1] owner", owner);
        console.log("[Size v1] feeRecipient", feeRecipient);

        NetworkConfiguration memory params = params(networkConfiguration);

        setupProduction(owner, feeRecipient, params);

        deployments.push(Deployment({name: "Size-implementation", addr: address(implementation)}));
        deployments.push(Deployment({name: "Size-proxy", addr: address(proxy)}));
        deployments.push(Deployment({name: "PriceFeed", addr: address(priceFeed)}));
        parameters.push(Parameter({key: "owner", value: Strings.toHexString(owner)}));
        parameters.push(Parameter({key: "feeRecipient", value: Strings.toHexString(feeRecipient)}));
        parameters.push(Parameter({key: "weth", value: Strings.toHexString(address(params.weth))}));
        parameters.push(
            Parameter({
                key: "underlyingCollateralToken",
                value: Strings.toHexString(address(params.underlyingCollateralToken))
            })
        );
        parameters.push(
            Parameter({key: "underlyingBorrowToken", value: Strings.toHexString(address(params.underlyingBorrowToken))})
        );
        parameters.push(
            Parameter({
                key: "priceFeedParams.baseAggregator",
                value: Strings.toHexString(address(params.priceFeedParams.baseAggregator))
            })
        );
        parameters.push(
            Parameter({
                key: "priceFeedParams.quoteAggregator",
                value: Strings.toHexString(address(params.priceFeedParams.quoteAggregator))
            })
        );
        parameters.push(
            Parameter({
                key: "priceFeedParams.baseStalePriceInterval",
                value: Strings.toString(params.priceFeedParams.baseStalePriceInterval)
            })
        );
        parameters.push(
            Parameter({
                key: "priceFeedParams.quoteStalePriceInterval",
                value: Strings.toString(params.priceFeedParams.quoteStalePriceInterval)
            })
        );
        parameters.push(
            Parameter({
                key: "priceFeedParams.sequencerUptimeFeed",
                value: Strings.toHexString(address(params.priceFeedParams.sequencerUptimeFeed))
            })
        );
        parameters.push(Parameter({key: "variablePool", value: Strings.toHexString(address(variablePool))}));

        parameters.push(Parameter({key: "fragmentationFee", value: Strings.toString(params.fragmentationFee)}));
        parameters.push(Parameter({key: "crOpening", value: Strings.toString(params.crOpening)}));
        parameters.push(Parameter({key: "crLiquidation", value: Strings.toString(params.crLiquidation)}));
        parameters.push(
            Parameter({key: "minimumCreditBorrowAToken", value: Strings.toString(params.minimumCreditBorrowAToken)})
        );
        parameters.push(Parameter({key: "borrowATokenCap", value: Strings.toString(params.borrowATokenCap)}));

        console.log("[Size v1] deployed\n");

        for (uint256 i = 0; i < deployments.length; i++) {
            console.log("[Size v1] Deployment: ", deployments[i].name, "\t", address(deployments[i].addr));
        }
        for (uint256 i = 0; i < parameters.length; i++) {
            console.log("[Size v1] Parameter:  ", parameters[i].key, "\t", parameters[i].value);
        }

        exportDeployments(networkConfiguration);

        console.log("[Size v1] done");

        return (deployments, parameters);
    }
}
