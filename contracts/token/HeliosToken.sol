// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import {ERC20}  from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract HeliosToken is ERC20 {
    IERC20 public immutable token;

    constructor(IERC20 _token) ERC20("Helios Liquidity Provider Token", "HLP-TKN") {
        token = _token;
    }

    function deposit(uint256 amount) external {
        require(amount > 0);

        _mint(msg.sender, amount);
        token.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0);

        _burn(msg.sender, amount);
        token.transfer(msg.sender, amount);
    }
}
