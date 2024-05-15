// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {FlashLoanReceiverBase} from "aave-v3-core/contracts/flashloan/base/FlashLoanReceiverBase.sol";
import {IPoolAddressesProvider} from "aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol";

contract MockAavePool is IPool {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external override {
        // Mock flash loan logic
        // Call the executeOperation function on the receiver
        FlashLoanReceiverBase receiver = FlashLoanReceiverBase(receiverAddress);
        receiver.executeOperation(assets, amounts, new uint256[](1), receiverAddress, params);
    }

    // Dummy implementations for required view functions
    function ADDRESSES_PROVIDER() external view override returns (IPoolAddressesProvider) {
        return IPoolAddressesProvider(address(0));
    }

    function FLASHLOAN_PREMIUM_TOTAL() external view override returns (uint128) {
        return 0;
    }

    function FLASHLOAN_PREMIUM_TO_PROTOCOL() external view override returns (uint128) {
        return 0;
    }

    function MAX_NUMBER_RESERVES() external view override returns (uint16) {
        return 0;
    }

    function MAX_STABLE_RATE_BORROW_SIZE_PERCENT() external view override returns (uint256) {
        return 0;
    }

}