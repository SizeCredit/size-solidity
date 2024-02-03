// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {NonTransferrableToken} from "./NonTransferrableToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// contract DebtToken is NonTransferrableToken {
//     // solhint-disable-next-line no-empty-blocks
//     constructor(address owner_, string memory name_, string memory symbol_, uint8 decimals_)
//         NonTransferrableToken(owner_, name_, symbol_, decimals_)
//     {}
// }

contract DebtToken is ERC20 {
    constructor(address, string memory name_, string memory symbol_, uint8) ERC20(name_, symbol_) {}

    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}
