//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPool} from "@aave/interfaces/IPool.sol";
import {Size} from "@src/Size.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {SizeMock} from "@test/mocks/SizeMock.sol";
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
    string constant TEST_CHAIN_NAME = "anvil";

    string root;
    string path;
    Deployment[] public deployments;
    Parameter[] public parameters;

    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function exportDeployments(string memory networkName) internal {
        // fetch already existing contracts
        root = vm.projectRoot();
        path = string.concat(root, "/deployments/");
        string memory chainIdStr = vm.toString(block.chainid);
        path = string.concat(path, string.concat(chainIdStr, ".json"));

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

        finalObject = vm.serializeString(".", "networkName", networkName);

        string memory commit = getCommitHash();
        finalObject = vm.serializeString(".", "commit", commit);

        vm.writeJson(finalObject, path);
    }

    function importDeployments()
        internal
        returns (SizeMock size, IPriceFeed priceFeed, IPool variablePool, USDC usdc, WETH weth, address owner)
    {
        root = vm.projectRoot();
        path = string.concat(root, "/deployments/");
        string memory chainIdStr = vm.toString(block.chainid);
        path = string.concat(path, string.concat(chainIdStr, ".json"));

        string memory json = vm.readFile(path);

        size = SizeMock(abi.decode(json.parseRaw(".deployments.Size-proxy"), (address)));
        priceFeed = IPriceFeed(abi.decode(json.parseRaw(".deployments.PriceFeed"), (address)));
        variablePool = IPool(abi.decode(json.parseRaw(".deployments.VariablePool"), (address)));
        usdc = USDC(abi.decode(json.parseRaw(".parameters.usdc"), (address)));
        weth = WETH(abi.decode(json.parseRaw(".parameters.weth"), (address)));
        owner = address(abi.decode(json.parseRaw(".parameters.owner"), (address)));
    }

    function getCommitHash() public returns (string memory) {
        string[] memory inputs = new string[](4);

        inputs[0] = "git";
        inputs[1] = "rev-parse";
        inputs[2] = "--short";
        inputs[3] = "HEAD";

        bytes memory res = vm.ffi(inputs);
        return string(res);
    }

    function findChainName() public returns (string memory) {
        uint256 thisChainId = block.chainid;
        string[2][] memory allRpcUrls = vm.rpcUrls();
        for (uint256 i = 0; i < allRpcUrls.length; i++) {
            try vm.createSelectFork(allRpcUrls[i][1]) {
                if (block.chainid == thisChainId) {
                    return allRpcUrls[i][0];
                }
            } catch {
                continue;
            }
        }
        revert InvalidChainId(thisChainId);
    }
}
