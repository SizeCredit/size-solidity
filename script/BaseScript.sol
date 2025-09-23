//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import {SizeFactory} from "@src/factory/SizeFactory.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";

import {ISizeV1_5} from "@deprecated/interfaces/ISizeV1_5.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Vm} from "forge-std/Vm.sol";
import {console2 as console} from "forge-std/console2.sol";

import {Safe} from "@safe-utils/Safe.sol";
import {Tenderly} from "@tenderly-utils/Tenderly.sol";

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
    using Safe for *;
    using Tenderly for *;

    Safe.Client safe;
    Tenderly.Client tenderly;

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

    modifier ignoreGas() {
        vm.pauseGasMetering();
        _;
        vm.resumeGasMetering();
    }

    modifier deleteVirtualTestnets() {
        Tenderly.VirtualTestnet[] memory vnets = tenderly.getVirtualTestnets();
        for (uint256 i = 0; i < vnets.length; i++) {
            tenderly.deleteVirtualTestnetById(vnets[i].id);
        }
        _;
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
        uint256 blockNumber,
        address borrowTokenVault
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
        finalObject =
            vm.serializeBytes(".", "data", abi.encodeCall(ISizeV1_5.reinitialize, (address(borrowTokenVault), users)));
        vm.writeJson(finalObject, path);
    }

    function importV1_5ReinitializeData(string memory networkConfiguration, EnumerableMap.AddressToUintMap storage map)
        internal
        returns (uint256 blockNumber, bytes memory data)
    {
        root = vm.projectRoot();
        path = string.concat(root, "/deployments/v1.5/");
        path = string.concat(path, string.concat(networkConfiguration, "-reinitialize-data", ".json"));

        string memory json = vm.readFile(path);

        // Deserialize the data
        address[] memory users = json.readAddressArray(".users");
        uint256[] memory values = json.readUintArray(".values");
        blockNumber = json.readUint(".blockNumber");
        data = json.readBytes(".data");

        // Populate the map
        for (uint256 i = 0; i < users.length; i++) {
            map.set(users[i], values[i]);
        }
    }

    function importSizeFactory(string memory networkConfiguration) internal returns (SizeFactory sizeFactory) {
        root = vm.projectRoot();
        path = string.concat(root, "/deployments/");
        path = string.concat(path, string.concat(networkConfiguration, ".json"));

        string memory json = vm.readFile(path);

        sizeFactory = SizeFactory(abi.decode(json.parseRaw(".deployments.SizeFactory-proxy"), (address)));
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

    function price(IPriceFeed priceFeed) internal view returns (string memory) {
        return format(priceFeed.getPrice(), priceFeed.decimals(), 2);
    }

    /// @dev returns XXX_XXX_XXX.dd, for example if value is 112307802362740077885500 and decimals is 18, it returns 112_307.80
    function format(uint256 value, uint256 decimals, uint256 precision) internal pure returns (string memory) {
        // Calculate the divisor to get the integer part
        uint256 divisor = 10 ** decimals;
        uint256 integerPart = value / divisor;
        uint256 fractionalPart = value % divisor;

        // Convert integer part to string with thousand separators
        string memory integerStr = _addThousandSeparators(integerPart);

        // Convert fractional part to 2 decimal places
        uint256 scaledFractional = (fractionalPart * (10 ** precision)) / divisor;

        // Format fractional part to always show precision digits
        string memory fractionalStr;
        if (scaledFractional < 10) {
            fractionalStr = string(abi.encodePacked("0", vm.toString(scaledFractional)));
        } else {
            fractionalStr = vm.toString(scaledFractional);
        }

        return string(abi.encodePacked(integerStr, ".", fractionalStr));
    }

    function _addThousandSeparators(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }

        string memory result = "";
        uint256 count = 0;

        while (value > 0) {
            if (count > 0 && count % 3 == 0) {
                result = string(abi.encodePacked("_", result));
            }

            uint256 digit = value % 10;
            result = string(abi.encodePacked(vm.toString(digit), result));
            value /= 10;
            count++;
        }

        return result;
    }
}
