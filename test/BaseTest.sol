// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {BaseTestFixed} from "@test/BaseTestFixed.sol";
import {BaseTestVariable} from "@test/BaseTestVariable.sol";
import {AssertsHelper} from "@test/helpers/AssertsHelper.sol";

contract BaseTest is Test, AssertsHelper, BaseTestFixed, BaseTestVariable {}
