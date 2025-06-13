// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface IERC4626Morpho is IERC4626 {
    function MORPHO() external view returns (address);
}
