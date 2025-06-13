// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC4626Fees} from "@openzeppelin/contracts/mocks/docs/ERC4626Fees.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract FeeOnEntryExitERC4626 is ERC4626Fees, Ownable {
    uint256 public entryFeeBasisPoints;
    uint256 public exitFeeBasisPoints;

    constructor(
        IERC20 underlying_,
        string memory name_,
        string memory symbol_,
        uint256 entryFeeBasisPoints_,
        uint256 exitFeeBasisPoints_
    ) ERC4626(underlying_) Ownable(msg.sender) ERC20(name_, symbol_) {
        entryFeeBasisPoints = entryFeeBasisPoints_;
        exitFeeBasisPoints = exitFeeBasisPoints_;
    }

    function _entryFeeBasisPoints() internal view virtual override returns (uint256) {
        return entryFeeBasisPoints;
    }

    function _exitFeeBasisPoints() internal view virtual override returns (uint256) {
        return exitFeeBasisPoints;
    }

    function _entryFeeRecipient() internal view virtual override returns (address) {
        return owner();
    }

    function _exitFeeRecipient() internal view virtual override returns (address) {
        return owner();
    }
}
