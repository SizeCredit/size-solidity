// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;
import "halmos-helpers-lib/HalmosHelpers.sol";
import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";
contract NonTransferrableRebasingTokenVaultPseudoCopy is NonTransferrableRebasingTokenVault {
    constructor() {
        bytes32 slot = _initializableStorageSlot();
        // re-enables initialize()
        assembly {
            sstore(slot, 0)
        }
    }

    mapping(address => bool) present_in_shares;
    mapping(uint256 => address) addresses_with_shares;
    uint256 number_addresses_with_shares = 0;

    function setSharesOf(address user, uint256 shares) override public onlyAdapter {
        if (present_in_shares[user] == false)
        {
            present_in_shares[user] = true;
            addresses_with_shares[number_addresses_with_shares] = user;
            number_addresses_with_shares++;
        }
        super.setSharesOf(user, shares);
    }

    /// @custom:halmos --loop 256
    function get_all_shares(address _vault) external view returns(uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < number_addresses_with_shares; i++) {
            address user = addresses_with_shares[i];
            if (vaultOf[user] == _vault) {
                sum += sharesOf[user];               
            }
        }
        return sum;
    }

}