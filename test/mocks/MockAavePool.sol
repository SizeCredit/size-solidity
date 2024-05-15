// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {FlashLoanReceiverBase} from "aave-v3-core/contracts/flashloan/base/FlashLoanReceiverBase.sol";

interface IMinimalPool {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

contract MockAavePool is IMinimalPool {
    struct FlashLoanParams {
        address receiverAddress;
        address[] assets;
        uint256[] amounts;
        uint256[] modes;
        address onBehalfOf;
        bytes params;
        uint16 referralCode;
    }

    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external override {
        FlashLoanParams memory flParams = FlashLoanParams({
            receiverAddress: receiverAddress,
            assets: assets,
            amounts: amounts,
            modes: modes,
            onBehalfOf: onBehalfOf,
            params: params,
            referralCode: referralCode
        });

        _executeFlashLoan(flParams);
    }

    function _executeFlashLoan(FlashLoanParams memory flParams) internal {
        // Mock flash loan logic
        // Call the executeOperation function on the receiver
        FlashLoanReceiverBase(flParams.receiverAddress).executeOperation(
            flParams.assets,
            flParams.amounts,
            new uint256[](1),
            flParams.receiverAddress,
            flParams.params
        );
    }
}