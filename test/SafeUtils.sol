// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IMultiSendCallOnly} from "@script/interfaces/IMultiSendCallOnly.sol";
import {ISafe} from "@script/interfaces/ISafe.sol";
import {Proxy} from "@test/Proxy.sol";
import {Test} from "forge-std/Test.sol";

contract SafeUtils is Test {
    function _getDataHash(ISafe safe, address to, uint256 value, bytes memory data) internal view returns (bytes32) {
        uint256 nonce = safe.nonce();
        return safe.getTransactionHash(to, value, data, uint8(0), 0, 0, 0, address(0), payable(address(0)), nonce);
    }

    function _execTransaction(ISafe safe, address to, bytes memory data) internal returns (bool success) {
        uint256 value = 0;
        bytes32 dataHash = _getDataHash(safe, to, value, data);

        address[] memory signers = safe.getOwners();
        bytes[] memory signatures = new bytes[](signers.length);
        for (uint256 i = 0; i < signers.length; i++) {
            address signer = signers[i];
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer, dataHash);
            signatures[i] = abi.encodePacked(r, s, v);
        }

        vm.prank(signers[0]);
        success =
            safe.execTransaction(to, value, data, 0, 0, 0, 0, address(0), payable(0), _encode(signers, signatures));
        assertTrue(success);
    }

    function _sort(address[] memory owners, bytes[] memory signatures)
        private
        pure
        returns (address[] memory sortedOwners, bytes[] memory sortedSignatures)
    {
        sortedOwners = new address[](owners.length);
        for (uint256 i = 0; i < owners.length; i++) {
            sortedOwners[i] = owners[i];
        }

        address temp;
        uint256 n = sortedOwners.length;

        for (uint256 i = 0; i < n - 1; i++) {
            for (uint256 j = 0; j < n - 1 - i; j++) {
                if (sortedOwners[j] > sortedOwners[j + 1]) {
                    temp = sortedOwners[j];
                    sortedOwners[j] = sortedOwners[j + 1];
                    sortedOwners[j + 1] = temp;
                }
            }
        }

        sortedSignatures = new bytes[](sortedOwners.length);
        for (uint256 i = 0; i < sortedOwners.length; i++) {
            for (uint256 j = 0; j < owners.length; j++) {
                if (sortedOwners[i] == owners[j]) {
                    sortedSignatures[i] = signatures[j];
                    break;
                }
            }
        }
    }

    function _encode(address[] memory owners, bytes[] memory signatures) private pure returns (bytes memory) {
        (, bytes[] memory sortedSignatures) = _sort(owners, signatures);
        bytes memory encoded;
        for (uint256 i = 0; i < sortedSignatures.length; i++) {
            encoded = abi.encodePacked(encoded, sortedSignatures[i]);
        }
        return encoded;
    }

    function _simulateSafeMultiSendCallOnly(ISafe safe, address to, bytes memory data) internal {
        address proxy = address(new Proxy(to));
        vm.etch(address(safe), address(proxy).code);
        (bool success,) = address(safe).call(abi.encodeCall(IMultiSendCallOnly.multiSend, (data)));
        assertTrue(success);
    }
}
