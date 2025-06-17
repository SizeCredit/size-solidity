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

import {Action, ActionsBitmap, Authorization} from "@src/factory/libraries/Authorization.sol";

// echidna . --contract CryticVaultsTester --config echidna.yaml
// medusa fuzz
contract CryticVaultsTester is CryticAsserts, Deploy, SetupLocal {
    NonTransferrableRebasingTokenVault private borrowTokenVault;
    MaliciousERC4626ReentrancyGeneric private maliciousVault;

    modifier asSender() {
        vm.prank(msg.sender);
        _;
    }

    modifier asSize() {
        vm.prank(address(size));
        _;
    }

    constructor() {
        setup();

        borrowTokenVault = size.data().borrowTokenVault;

        maliciousVault = MaliciousERC4626ReentrancyGeneric(address(vaultMaliciousReentrancyGeneric));

        borrowTokenVault.setVaultAdapter(address(maliciousVault), bytes32("ERC4626Adapter"));
        maliciousVault.setSize(size);
        maliciousVault.setOnBehalfOf(USER2);

        Action[] memory actions = new Action[](3);
        actions[0] = Action.DEPOSIT;
        actions[1] = Action.WITHDRAW;
        actions[2] = Action.SET_VAULT;
        sizeFactory.setAuthorization(address(maliciousVault), Authorization.getActionsBitmap(actions));
    }

    function token_approve(address _token, uint256 _amount) public asSender {
        IERC20Metadata(_token).approve(address(size), _amount);
    }

    function size_deposit(address _token, uint256 _amount, address _to) public asSender {
        size.deposit(DepositParams({token: _token, amount: _amount, to: _to}));
    }

    function size_withdraw(address _token, uint256 _amount, address _to) public asSender {
        size.withdraw(WithdrawParams({token: _token, amount: _amount, to: _to}));
    }

    function borrowTokenVault_transferFrom(address _from, address _to, uint256 _amount) public asSize {
        borrowTokenVault.transferFrom(_from, _to, _amount);
    }

    function borrowTokenVault_setVault(address _user, address _vault, bool _forfeitOldShares) public asSize {
        borrowTokenVault.setVault(_user, _vault, _forfeitOldShares);
    }

    function maliciousVault_setOnBehalfOf(address _user) public asSender {
        maliciousVault.setOnBehalfOf(_user);
    }

    function maliciousVault_setReenterCount(uint256 _reenterCount) public asSender {
        maliciousVault.setReenterCount(_reenterCount);
    }

    function maliciousVault_setOperation(bytes4 _operation) public asSender {
        maliciousVault.setOperation(_operation);
    }

    function maliciousVault_setForfeitOldShares(bool _forfeitOldShares) public asSender {
        maliciousVault.setForfeitOldShares(_forfeitOldShares);
    }
}
