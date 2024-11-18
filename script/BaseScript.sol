//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ISize} from "@src/interfaces/ISize.sol";

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Vm} from "forge-std/Vm.sol";
import {console2 as console} from "forge-std/console2.sol";

struct Deployment {
    string name;
    address addr;
}

struct Parameter {
    string key;
    string value;
}

abstract contract BaseScript is Script {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
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
        returns (ISize size, IPriceFeed priceFeed, address owner)
    {
        root = vm.projectRoot();
        path = string.concat(root, "/deployments/");
        path = string.concat(path, string.concat(networkConfiguration, ".json"));

        string memory json = vm.readFile(path);

        size = ISize(abi.decode(json.parseRaw(".deployments.Size-proxy"), (address)));
        priceFeed = IPriceFeed(abi.decode(json.parseRaw(".deployments.PriceFeed"), (address)));
        owner = address(abi.decode(json.parseRaw(".parameters.owner"), (address)));
    }

    function exportV1_5ReinitializeData(
        string memory networkConfiguration,
        EnumerableMap.AddressToUintMap storage map,
        uint256 blockNumber
    ) internal {
        root = vm.projectRoot();
        path = string.concat(root, "/deployments/v1.5/");
        path = string.concat(path, string.concat(networkConfiguration, "-reinitialize-data", ".json"));

        string memory finalObject;
        address[] memory users = map.keys();
        uint256[] memory values = new uint256[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            values[i] = map.get(users[i]);
        }
        finalObject = vm.serializeAddress(".", "users", users);
        finalObject = vm.serializeUint(".", "values", values);
        finalObject = vm.serializeUint(".", "blockNumber", blockNumber);

        vm.writeJson(finalObject, path);
    }

    function importV1_5ReinitializeData(string memory networkConfiguration, EnumerableMap.AddressToUintMap storage map)
        internal
        returns (uint256 blockNumber)
    {
        root = vm.projectRoot();
        path = string.concat(root, "/deployments/v1.5/");
        path = string.concat(path, string.concat(networkConfiguration, "-reinitialize-data", ".json"));

        string memory json = vm.readFile(path);

        // Deserialize the data
        address[] memory users = json.readAddressArray(".users");
        uint256[] memory values = json.readUintArray(".values");
        blockNumber = json.readUint(".blockNumber");

        // Populate the map
        for (uint256 i = 0; i < users.length; i++) {
            map.set(users[i], values[i]);
        }
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
