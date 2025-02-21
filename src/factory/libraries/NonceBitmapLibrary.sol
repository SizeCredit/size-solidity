// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @notice User-defined value type for a 128-bit nonce
type Nonce is uint128;

/// @notice User-defined value type for a 128-bit bitmap
type Bitmap is uint128;

/// @notice User-defined value type for a `nonce | bitmap` struct
/// @dev The nonce is the first 128 bits and the bitmap is the last 128 bits, in little-endian order
type NonceBitmap is uint256;

/// @title NonceBitmapLibrary
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @dev This library is used to manage the nonce and bitmap
/// @dev This library does not validate the input values of nonces or bitmaps
library NonceBitmapLibrary {
    /// @notice Converts a Bitmap to a uint128
    /// @param bitmap The Bitmap to convert
    /// @return The uint128 representation of the Bitmap
    function toUint128(Bitmap bitmap) internal pure returns (uint128) {
        return Bitmap.unwrap(bitmap);
    }

    /// @notice Converts a uint128 to a Bitmap
    /// @param value The uint128 value to convert
    /// @return The Bitmap
    function toBitmap(uint128 value) internal pure returns (Bitmap) {
        return Bitmap.wrap(value);
    }

    /// @notice Converts a Nonce to a uint128
    /// @param nonce The Nonce to convert
    /// @return The uint128 representation of the Nonce
    function toUint128(Nonce nonce) internal pure returns (uint128) {
        return Nonce.unwrap(nonce);
    }

    /// @notice Converts a uint128 to a Nonce
    /// @param value The uint128 value to convert
    /// @return The Nonce
    function toNonce(uint128 value) internal pure returns (Nonce) {
        return Nonce.wrap(value);
    }

    /// @notice Increments a nonce
    /// @param nonce The nonce to increment
    /// @return The incremented nonce
    function increment(Nonce nonce) internal pure returns (Nonce) {
        return toNonce(toUint128(nonce) + 1);
    }

    /// @notice Converts a nonce and bitmap to a NonceBitmap
    /// @dev This function does not validate the input values to be valid
    /// @param nonce The nonce
    /// @param bitmap The bitmap
    /// @return The NonceBitmap
    function toNonceBitmap(Nonce nonce, Bitmap bitmap) internal pure returns (NonceBitmap) {
        return NonceBitmap.wrap(toUint128(nonce) << 128 | toUint128(bitmap));
    }

    /// @notice Converts a NonceBitmap to a uint256
    /// @dev This function does not validate the input value to be a valid NonceBitmap
    /// @param nonceBitmap The NonceBitmap to convert
    /// @return The uint256 value
    function toUint256(NonceBitmap nonceBitmap) internal pure returns (uint256) {
        return NonceBitmap.unwrap(nonceBitmap);
    }

    /// @notice Converts a `nonce | actions bitmap` to a uint256
    /// @dev This function does not validate the input value to be a valid `nonce | actions bitmap`
    /// @param value The `nonce | actions bitmap` to convert
    /// @return The uint256 value
    function toNonceBitmap(uint256 value) internal pure returns (NonceBitmap) {
        return NonceBitmap.wrap(value);
    }

    /// @notice Get the nonce from a NonceBitmap
    /// @dev This function does not validate the input value to be a valid NonceBitmap
    /// @param nonceBitmap The NonceBitmap to convert
    /// @return The nonce
    function getNonce(NonceBitmap nonceBitmap) internal pure returns (Nonce) {
        return toNonce(uint128(toUint256(nonceBitmap) >> 128));
    }

    /// @notice Get the bitmap from a NonceBitmap
    /// @dev This function does not validate the input value to be a valid NonceBitmap
    /// @param nonceBitmap The NonceBitmap to convert
    /// @return The bitmap
    function getBitmap(NonceBitmap nonceBitmap) internal pure returns (Bitmap) {
        return toBitmap(uint128(toUint256(nonceBitmap)));
    }

    /// @notice Returns the null nonce
    /// @return The null nonce
    function nullNonce() internal pure returns (Nonce) {
        return toNonce(0);
    }

    /// @notice Returns the null actions bitmap
    /// @dev The null actions bitmap is the actions bitmap that represents no actions
    /// @return The null actions bitmap
    function nullBitmap() internal pure returns (Bitmap) {
        return toBitmap(0);
    }

    /// @notice Returns the null NonceBitmap
    /// @return The null NonceBitmap
    function nullNonceBitmap() internal pure returns (NonceBitmap) {
        return toNonceBitmap(0);
    }
}
