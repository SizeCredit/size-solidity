// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {BaseTestFixed} from "@test/BaseTestFixed.sol";
import {AssertsHelper} from "@test/helpers/AssertsHelper.sol";

contract BaseTest is Test, AssertsHelper, BaseTestFixed {}
