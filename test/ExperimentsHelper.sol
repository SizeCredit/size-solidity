// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@solplot/Plot.sol";
import "../src/libraries/UserLibrary.sol";

abstract contract ExperimentsHelper is Test, Plot {
    function plot(string memory filename, BorrowerStatus memory self) internal {
        try vm.createDir("./plots", false) {} catch {}
        try vm.removeFile(string.concat("./plots/", filename, ".csv")) {} catch {}

        uint256 length = self.RANC.length;

        // Use first row as legend
        // Make sure the same amount of columns are included for the legend
        vm.writeLine(string.concat("./plots/", filename, ".csv"), "x axis,expectedFV,unlocked,dueFV,RANC,");

        // Create input csv
        for (uint256 i; i < length; i++) {
            int256[] memory cols = new int256[](5);

            cols[0] = int256(i * 1e18);
            cols[1] = int256(self.expectedFV[i]);
            cols[2] = int256(self.unlocked[i]);
            cols[3] = int256(self.dueFV[i]);
            cols[4] = int256(self.RANC[i]);

            writeRowToCSV(string.concat("./plots/", filename, ".csv"), cols);
        }

        // Create output svg with values denominated in wad
        plot({
            inputCsv: string.concat("./plots/", filename, ".csv"),
            outputSvg: string.concat("./plots/", filename, ".svg"),
            inputDecimals: 18,
            totalColumns: 5,
            legend: true
        });
    }
}
