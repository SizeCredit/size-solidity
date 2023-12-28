// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

struct YieldCurve {
    uint256[] timeBuckets;
    uint256[] rates;
}

library YieldCurveLibrary {}
