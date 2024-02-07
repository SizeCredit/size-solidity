// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Plot} from "@solplot/Plot.sol";
import {Test} from "forge-std/Test.sol";

abstract contract ExperimentsHelper is Test, Plot {
    function plot(string memory filename, uint256[] memory data) internal {
        try vm.createDir("./plots", false) {} catch {}
        try vm.removeFile(string.concat("./plots/", filename, ".csv")) {} catch {}

        uint8 columns = 2;

        // Use first row as legend
        // Make sure the same amount of columns are included for the legend
        vm.writeLine(string.concat("./plots/", filename, ".csv"), "x axis,expectedFV,unlocked,dueFV,RANC,");

        // Create input csv
        for (uint256 i; i < data.length; i++) {
            int256[] memory cols = new int256[](columns);

            uint256 j = 0;
            cols[j++] = int256(i * 1e18);
            cols[j++] = int256(data[i]);

            writeRowToCSV(string.concat("./plots/", filename, ".csv"), cols);
        }

        // Create output svg with values denominated in wad
        plot({
            inputCsv: string.concat("./plots/", filename, ".csv"),
            outputSvg: string.concat("./plots/", filename, ".svg"),
            inputDecimals: 18,
            totalColumns: columns,
            legend: true
        });
    }
}
