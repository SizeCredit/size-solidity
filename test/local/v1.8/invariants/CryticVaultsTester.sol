// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";

import {CryticAsserts} from "@chimera/CryticAsserts.sol";
import {vm} from "@chimera/Hevm.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC4626 as ERC4626OpenZeppelin} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";

import {Deploy} from "@script/Deploy.sol";
import {SetupLocal} from "@test/invariants/SetupLocal.sol";
import {SimplePool} from "@test/local/token/differential/mocks/SimplePool.sol";
import {USDC} from "@test/mocks/USDC.sol";
import {MaliciousERC4626ReentrancyGeneric} from "@test/mocks/vaults/MaliciousERC4626ReentrancyGeneric.sol";

import {DepositParams} from "@src/market/libraries/actions/Deposit.sol";
import {WithdrawParams} from "@src/market/libraries/actions/Withdraw.sol";

// echidna . --contract CryticVaultsTester --config echidna.yaml
// medusa fuzz
contract CryticVaultsTester is CryticAsserts, Deploy, SetupLocal {
    string private constant ERROR = "ERROR";

    NonTransferrableRebasingTokenVault private borrowTokenVault;

    constructor() {
        setup();

        borrowTokenVault = size.data().borrowTokenVault;

        borrowTokenVault.setVaultAdapter(address(vaultMaliciousReentrancyGeneric), bytes32("ERC4626Adapter"));
        MaliciousERC4626ReentrancyGeneric(address(vaultMaliciousReentrancyGeneric)).setSize(size);
        MaliciousERC4626ReentrancyGeneric(address(vaultMaliciousReentrancyGeneric)).setOnBehalfOf(USER2);
    }

    function approve(address _token, uint256 _amount) public {
        vm.prank(msg.sender);
        IERC20Metadata(_token).approve(address(size), _amount);
    }

    function deposit(address _token, uint256 _amount, address _to) public {
        vm.prank(msg.sender);
        size.deposit(DepositParams({token: _token, amount: _amount, to: _to}));
    }

    function withdraw(address _token, uint256 _amount, address _to) public {
        vm.prank(msg.sender);
        size.withdraw(WithdrawParams({token: _token, amount: _amount, to: _to}));
    }

    function transferFrom(address _from, address _to, uint256 _amount) public {
        vm.prank(address(size));
        borrowTokenVault.transferFrom(_from, _to, _amount);
    }

    function setVault(address _user, address _vault, bool _forfeitOldShares) public {
        vm.prank(address(size));
        borrowTokenVault.setVault(_user, _vault, _forfeitOldShares);
    }
}
