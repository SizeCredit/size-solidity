// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import {Math} from "@src/core/libraries/Math.sol";
import {NonTransferrableToken} from "@src/core/token/NonTransferrableToken.sol";

import {Errors} from "@src/core/libraries/Errors.sol";

/// @title NonTransferrableScaledToken
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice An ERC-20 that is not transferrable from outside of the protocol
/// @dev The contract owner (i.e. the Size contract) can still mint, burn, and transfer tokens
contract NonTransferrableScaledToken is NonTransferrableToken {
    IPool private immutable variablePool;
    IERC20Metadata private immutable underlyingToken;

    event TransferUnscaled(address indexed from, address indexed to, uint256 value);

    // solhint-disable-next-line no-empty-blocks
    constructor(
        IPool variablePool_,
        IERC20Metadata underlyingToken_,
        address owner_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) NonTransferrableToken(owner_, name_, symbol_, decimals_) {
        if (address(variablePool_) == address(0) || address(underlyingToken_) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        variablePool = variablePool_;
        underlyingToken = underlyingToken_;
    }

    function mint(address, uint256) external view override onlyOwner {
        revert Errors.NOT_SUPPORTED();
    }

    function mintScaled(address to, uint256 scaledAmount) external onlyOwner {
        _mint(to, scaledAmount);
        emit TransferUnscaled(address(0), to, _unscale(scaledAmount));
    }

    function burn(address, uint256) external view override onlyOwner {
        revert Errors.NOT_SUPPORTED();
    }

    function burnScaled(address from, uint256 scaledAmount) external onlyOwner {
        _burn(from, scaledAmount);
        emit TransferUnscaled(from, address(0), _unscale(scaledAmount));
    }

    function transferFrom(address from, address to, uint256 value) public virtual override onlyOwner returns (bool) {
        uint256 scaledAmount = Math.mulDivDown(value, WadRayMath.RAY, liquidityIndex());

        _burn(from, scaledAmount);
        _mint(to, scaledAmount);

        emit TransferUnscaled(from, to, value);

        return true;
    }

    function transfer(address to, uint256 value) public virtual override onlyOwner returns (bool) {
        return transferFrom(msg.sender, to, value);
    }

    function scaledBalanceOf(address account) public view returns (uint256) {
        return super.balanceOf(account);
    }

    function _unscale(uint256 scaledAmount) internal view returns (uint256) {
        return Math.mulDivDown(scaledAmount, liquidityIndex(), WadRayMath.RAY);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _unscale(scaledBalanceOf(account));
    }

    function scaledTotalSupply() public view returns (uint256) {
        return super.totalSupply();
    }

    function totalSupply() public view override returns (uint256) {
        return _unscale(scaledTotalSupply());
    }

    function liquidityIndex() public view returns (uint256) {
        return variablePool.getReserveNormalizedIncome(address(underlyingToken));
    }
}
