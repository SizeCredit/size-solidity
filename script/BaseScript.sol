//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPool} from "@aave/interfaces/IPool.sol";
import {ISize} from "@src/interfaces/ISize.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {USDC} from "@test/mocks/USDC.sol";
import {WETH} from "@test/mocks/WETH.sol";
import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Vm} from "forge-std/Vm.sol";

struct Deployment {
    string name;
    address addr;
}

struct Parameter {
    string key;
    string value;
}

abstract contract BaseScript is Script {
    using stdJson for string;

    error InvalidChainId(uint256 chainid);
    error InvalidPrivateKey(string privateKey);

    string constant TEST_MNEMONIC = "test test test test test test test test test test test junk";
    string constant TEST_NETWORK_CONFIGURATION = "anvil";

    string root;
    string path;
    Deployment[] internal deployments;
    Parameter[] internal parameters;

    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function exportDeployments(string memory networkConfiguration) internal {
        // fetch already existing contracts
        root = vm.projectRoot();
        path = string.concat(root, "/deployments/");
        path = string.concat(path, string.concat(networkConfiguration, ".json"));

        string memory finalObject;
        string memory deploymentsObject;
        string memory parametersObject;
        for (uint256 i = 0; i < deployments.length; i++) {
            deploymentsObject = vm.serializeAddress(".deployments", deployments[i].name, deployments[i].addr);
        }
        for (uint256 i = 0; i < parameters.length; i++) {
            parametersObject = vm.serializeString(".parameters", parameters[i].key, parameters[i].value);
        }
        finalObject = vm.serializeString(".", "deployments", deploymentsObject);
        finalObject = vm.serializeString(".", "parameters", parametersObject);

        finalObject = vm.serializeString(".", "networkConfiguration", networkConfiguration);

        finalObject = vm.serializeString(".", "commit", getCommitHash());
        finalObject = vm.serializeString(".", "chainId", vm.toString(block.chainid));

        vm.writeJson(finalObject, path);
    }

    function importDeployments(string memory networkConfiguration)
        internal
        returns (ISize size, IPriceFeed priceFeed, IPool variablePool, USDC usdc, WETH weth, address owner)
    {
        root = vm.projectRoot();
        path = string.concat(root, "/deployments/");
        path = string.concat(path, string.concat(networkConfiguration, ".json"));

        string memory json = vm.readFile(path);

        size = ISize(abi.decode(json.parseRaw(".deployments.Size-proxy"), (address)));
        priceFeed = IPriceFeed(abi.decode(json.parseRaw(".deployments.PriceFeed"), (address)));
        variablePool = IPool(abi.decode(json.parseRaw(".parameters.variablePool"), (address)));
        usdc = USDC(abi.decode(json.parseRaw(".parameters.usdc"), (address)));
        weth = WETH(abi.decode(json.parseRaw(".parameters.weth"), (address)));
        owner = address(abi.decode(json.parseRaw(".parameters.owner"), (address)));
    }

    function getCommitHash() internal returns (string memory) {
        string[] memory inputs = new string[](4);

        inputs[0] = "git";
        inputs[1] = "rev-parse";
        inputs[2] = "--short";
        inputs[3] = "HEAD";

        bytes memory res = vm.ffi(inputs);
        return string(res);
    }
}
