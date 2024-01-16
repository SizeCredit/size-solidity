// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {BaseTestFixed} from "./BaseTestFixed.sol";
import {BaseTestVariable} from "./BaseTestVariable.sol";
import {AssertsHelper} from "./helpers/AssertsHelper.sol";

contract BaseTest is Test, AssertsHelper, BaseTestFixed, BaseTestVariable {}
