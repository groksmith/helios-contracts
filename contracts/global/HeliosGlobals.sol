// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../interfaces/ISubFactory.sol";
import "../interfaces/IHeliosGlobals.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// HeliosGlobals maintains a central source of parameters and allowLists for the Helios protocol.
contract HeliosGlobals is AccessControl, IHeliosGlobals {
    bytes32 public constant USER_ROLE = keccak256("USER");

    bool public override protocolPaused; // Switch to pause the functionality of the entire protocol.
    mapping(address => bool) public override isValidPoolFactory; // Mapping of valid Pool Factories
    mapping(address => bool) public override isValidLiquidityAsset; // Mapping of valid Liquidity Assets
    mapping(address => mapping(address => bool)) public override validSubFactories;

    event ProtocolPaused(bool pause);
    event Initialized();
    event LiquidityAssetSet(address asset, uint256 decimals, string symbol, bool valid);
    event ValidPoolFactorySet(address indexed poolFactory, bool valid);
    event ValidSubFactorySet(address indexed superFactory, address indexed subFactory, bool valid);

    constructor(address admin) {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setRoleAdmin(USER_ROLE, DEFAULT_ADMIN_ROLE);
        emit Initialized();
    }

    function isAdmin(address account) public view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }

    // Sets the paused/unpaused state of the protocol. Only the Admin can call this function
    function setProtocolPause(bool pause) external onlyAdmin {
        protocolPaused = pause;
        emit ProtocolPaused(pause);
    }

    // Sets the validity of a PoolFactory. Only the Admin can call this function
    function setValidPoolFactory(address poolFactory, bool valid) external onlyAdmin {
        isValidPoolFactory[poolFactory] = valid;
        emit ValidPoolFactorySet(poolFactory, valid);
    }

    // Sets the validity of a sub factory as it relates to a super factory. Only the Admin can call this function
    function setValidSubFactory(address superFactory, address subFactory, bool valid) external onlyAdmin {
        require(isValidPoolFactory[superFactory], "HG:INV_SUPER_F");
        validSubFactories[superFactory][subFactory] = valid;
        emit ValidSubFactorySet(superFactory, subFactory, valid);
    }

    // Sets the validity of an asset for liquidity in Pools. Only the Admin can call this function
    function setLiquidityAsset(address asset, bool valid) external onlyAdmin {
        isValidLiquidityAsset[asset] = valid;
        emit LiquidityAssetSet(asset, IERC20Metadata(asset).decimals(), IERC20Metadata(asset).symbol(), valid);
    }

    // Checks that a subFactory is valid as it relates to a super factory
    function isValidSubFactory(address superFactory, address subFactory, uint8 factoryType)
        external
        view
        returns (bool)
    {
        return validSubFactories[superFactory][subFactory] && ISubFactory(subFactory).factoryType() == factoryType;
    }

    /// @dev Restricted to members of the admin role.
    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "HG:NOT_ADMIN");
        _;
    }
}
