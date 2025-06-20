// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";

import {Asserts} from "@chimera/Asserts.sol";
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
import {SetupLocal} from "@test/invariants/SetupLocal.sol";

abstract contract VaultsTargetFunctions is Asserts, Deploy, SetupLocal {
    uint256 private constant MAX_REENTER_COUNT = 5;

    NonTransferrableRebasingTokenVault private borrowTokenVault;
    MaliciousERC4626ReentrancyGeneric private maliciousVault;
    address private token;
    address internal sender;

    function setup() internal override {
        super.setup();
        _deploySizeMarket2();

        borrowTokenVault = size.data().borrowTokenVault;
        token = address(usdc);

        maliciousVault = MaliciousERC4626ReentrancyGeneric(address(vaultMaliciousReentrancyGeneric));

        borrowTokenVault.setVaultAdapter(address(maliciousVault), bytes32("ERC4626Adapter"));
        maliciousVault.setOnBehalfOf(USER2);

        Action[] memory actions = new Action[](3);
        actions[0] = Action.DEPOSIT;
        actions[1] = Action.WITHDRAW;
        actions[2] = Action.SET_VAULT;
        ActionsBitmap actionsBitmap = Authorization.getActionsBitmap(actions);
        vm.prank(USER2);
        sizeFactory.setAuthorization(address(maliciousVault), actionsBitmap);
    }

    modifier getSender() virtual {
        sender = msg.sender;
        _;
    }

    function token_approve(uint256 _amount) public getSender {
        vm.prank(sender);
        IERC20Metadata(token).approve(address(size), _amount);
    }

    function size_deposit(uint256 _amount, address _to) public getSender {
        vm.prank(sender);
        size.deposit(DepositParams({token: token, amount: _amount, to: _to}));
    }

    function size_withdraw(uint256 _amount, address _to) public getSender {
        vm.prank(sender);
        size.withdraw(WithdrawParams({token: token, amount: _amount, to: _to}));
    }

    function borrowTokenVault_transferFrom(address _from, address _to, uint256 _amount) public {
        vm.prank(address(size));
        borrowTokenVault.transferFrom(_from, _to, _amount);
    }

    function borrowTokenVault_setVault(address _user, address _vault, bool _forfeitOldShares) public {
        _user = _getRandomUser(_user);
        _vault = _getRandomVault(_vault);
        vm.prank(address(size));
        borrowTokenVault.setVault(_user, _vault, _forfeitOldShares);
    }

    function maliciousVault_setSize(bool _isSize1) public {
        maliciousVault.setSize(_isSize1 ? size1 : size2);
    }

    function maliciousVault_setReenterCount(uint256 _reenterCount) public {
        _reenterCount = between(_reenterCount, 0, MAX_REENTER_COUNT);
        maliciousVault.setReenterCount(_reenterCount);
    }

    function maliciousVault_setOperation(bytes4 _operation) public {
        maliciousVault.setOperation(_operation);
    }

    function maliciousVault_setForfeitOldShares(bool _forfeitOldShares) public {
        maliciousVault.setForfeitOldShares(_forfeitOldShares);
    }
}
