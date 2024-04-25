// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Size} from "@src/Size.sol";
import {
    CREDIT_POSITION_ID_START,
    CreditPosition,
    DEBT_POSITION_ID_START,
    DebtPosition,
    LoanStatus
} from "@src/libraries/fixed/LoanLibrary.sol";
import {Logger} from "@test/Logger.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract GetPositionsScript is Script, Logger {
    function run() external view {
        console.log("GetPositions...");

        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        address userAddress = vm.envAddress("USER_ADDRESS");
        Size size = Size(sizeContractAddress);

        (uint256 debtPositionsCount, uint256 creditPositionsCount) = size.getPositionsCount();
        uint256 totalDebt;

        for (uint256 i = 0; i < debtPositionsCount; ++i) {
            uint256 debtPositionId = DEBT_POSITION_ID_START + i;
            DebtPosition memory debtPosition = size.getDebtPosition(debtPositionId);
            if (debtPosition.borrower == userAddress) {
                console.log("DebtPosition: %s", debtPositionId);
                totalDebt += debtPosition.faceValue + debtPosition.repayFee + debtPosition.overdueLiquidatorReward;
                _log(debtPosition);
            }
            console.log("");
        }

        for (uint256 i = 0; i < creditPositionsCount; ++i) {
            uint256 creditPositionId = CREDIT_POSITION_ID_START + i;
            CreditPosition memory creditPosition = size.getCreditPosition(creditPositionId);
            console.log("CreditPosition: %s", creditPositionId);
            if (creditPosition.lender == userAddress) {
                _log(creditPosition);
            }
            console.log("");
        }

        console.log("total debt", size.data().debtToken.balanceOf(userAddress));
        console.log("positions debt", totalDebt);
    }
}
