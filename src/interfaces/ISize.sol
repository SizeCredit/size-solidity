// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ISizeErrors} from "./ISizeErrors.sol";
import {ISizeEvents} from "./ISizeEvents.sol";
import {ISizeFunctions} from "./ISizeFunctions.sol";

interface ISize is ISizeErrors, ISizeEvents, ISizeFunctions {}
