// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../src/Size.sol";
import "../src/libraries/fixed/YieldCurveLibrary.sol";
import "forge-std/Script.sol";

contract BorrowMarketOrder is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        address lender = 0xD20baecCd9F77fAA9E2C2B185F33483D7911f9C8;

        Size sizeContract = Size(sizeContractAddress);

        uint256[] memory virtualCollateralFixedLoanIds = new uint256[](2);
        virtualCollateralFixedLoanIds[0] = 0;
        virtualCollateralFixedLoanIds[1] = 1;

        BorrowAsMarketOrderParams memory params = BorrowAsMarketOrderParams({
            lender: lender,
            amount: 1e6,
            dueDate: 2592e3,
            exactAmountIn: false,
            virtualCollateralFixedLoanIds: virtualCollateralFixedLoanIds
        });

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.borrowAsMarketOrder(params);
        vm.stopBroadcast();
    }
}

/* struct BorrowAsMarketOrderParams {
    address lender;
    uint256 amount; // in decimals (e.g. 1_000e6 for 1000 USDC or 1_000e18 for 1000 WETH)
    uint256 dueDate;
    bool exactAmountIn;
    uint256[] virtualCollateralFixedLoanIds;
} */
