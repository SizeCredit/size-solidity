// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import {Math} from "@src/libraries/Math.sol";
import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";

import {Errors} from "@src/libraries/Errors.sol";

/// @title NonTransferrableScaledToken
/// @notice An ERC-20 that is not transferrable from outside of the protocol
/// @dev The contract owner (i.e. the Size contract) can still mint, burn, and transfer tokens
contract NonTransferrableScaledToken is NonTransferrableToken {
    IPool private immutable variablePool;
    IERC20Metadata private immutable underlyingToken;

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
    }

    function burn(address, uint256) external view override onlyOwner {
        revert Errors.NOT_SUPPORTED();
    }

    function burnScaled(address from, uint256 scaledAmount) external onlyOwner {
        _burn(from, scaledAmount);
    }

    function transferFrom(address from, address to, uint256 value) public virtual override onlyOwner returns (bool) {
        uint256 scaledAmount = Math.mulDivDown(value, WadRayMath.RAY, liquidityIndex());

        _burn(from, scaledAmount);
        _mint(to, scaledAmount);

        return true;
    }

    function transfer(address to, uint256 value) public virtual override onlyOwner returns (bool) {
        return transferFrom(msg.sender, to, value);
    }

    function scaledBalanceOf(address account) public view returns (uint256) {
        return super.balanceOf(account);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return Math.mulDivDown(scaledBalanceOf(account), liquidityIndex(), WadRayMath.RAY);
    }

    function scaledTotalSupply() public view returns (uint256) {
        return super.totalSupply();
    }

    function totalSupply() public view override returns (uint256) {
        return Math.mulDivDown(scaledTotalSupply(), liquidityIndex(), WadRayMath.RAY);
    }

    function liquidityIndex() public view returns (uint256) {
        return variablePool.getReserveNormalizedIncome(address(underlyingToken));
    }
}
