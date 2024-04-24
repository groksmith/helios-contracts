pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Used for testing only
contract MockTokenERC20 is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }

    function burn(address _of, uint256 _amount) external {
        _burn(_of, _amount);
    }

    function decimals() public view override returns (uint8) {
        return 6;
    }
}
