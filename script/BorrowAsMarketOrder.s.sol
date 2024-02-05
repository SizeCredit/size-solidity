// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../src/Size.sol";
import "../src/libraries/fixed/YieldCurveLibrary.sol";
import "forge-std/Script.sol";
import "./TimestampHelper.sol";

contract BorrowMarketOrder is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        address wallet1 = 0xD20baecCd9F77fAA9E2C2B185F33483D7911f9C8;
        address wallet2 = 0x979Af411D048b453E3334C95F392012B3BbD6215;

        TimestampHelper helper = new TimestampHelper();
        uint256 currentTimestamp = helper.getCurrentTimestamp();
        uint256 dueDate = currentTimestamp + 172800;   //60 * 60 * 24 * 28; // 300 days from now

        Size sizeContract = Size(sizeContractAddress);

        /* uint256[] memory virtualCollateralFixedLoanIds = new uint256[](2);
        virtualCollateralFixedLoanIds[0] = uint256(0);
        virtualCollateralFixedLoanIds[1] = uint256(0); */

        BorrowAsMarketOrderParams memory params = BorrowAsMarketOrderParams({
            lender: wallet1,
            amount: 1e6,
            dueDate: dueDate,
            exactAmountIn: false,
            virtualCollateralFixedLoanIds: new uint256[](0)
        });

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.borrowAsMarketOrder(params);
        vm.stopBroadcast();
    }
}
