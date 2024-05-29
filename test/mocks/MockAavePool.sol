// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {FlashLoanReceiverBase} from "aave-v3-core/contracts/flashloan/base/FlashLoanReceiverBase.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

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

    function getPool() external view returns (address);
}

contract MockAavePool is IMinimalPool {
    address public pool;

    constructor() {
        pool = address(this);
    }

    struct FlashLoanParams {
        address receiverAddress;
        address[] assets;
        uint256[] amounts;
        uint256[] modes;
        address onBehalfOf;
        bytes params;
        uint16 referralCode;
    }

    function getPool() external view returns (address) {
        return pool;
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
        // Transfer the flash loan amounts to the receiver
        for (uint256 i = 0; i < flParams.assets.length; i++) {
            IERC20(flParams.assets[i]).transfer(flParams.receiverAddress, flParams.amounts[i]);
        }

        // Call the executeOperation function on the receiver
        FlashLoanReceiverBase(flParams.receiverAddress).executeOperation(
            flParams.assets, flParams.amounts, new uint256[](1), flParams.receiverAddress, flParams.params
        );

        // Ensure the receiver has repaid the loan plus premium
        for (uint256 i = 0; i < flParams.assets.length; i++) {
            uint256 amountOwed = flParams.amounts[i]; // Assuming no premium for simplicity
            require(IERC20(flParams.assets[i]).balanceOf(address(this)) >= amountOwed, "Flash loan not repaid");
        }
    }
}
