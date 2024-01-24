// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ISizeFixed} from "./ISizeFixed.sol";
import {ISizeVariable} from "./ISizeVariable.sol";

interface ISize is ISizeFixed, ISizeVariable {}
