// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../interfaces/ISubFactory.sol";
import "../interfaces/IHeliosGlobals.sol";

// HeliosGlobals maintains a central source of parameters and allowLists for the Helios protocol.
contract HeliosGlobals is IHeliosGlobals {
    address public override globalAdmin;        // The Global Admin of the whole network. Has the power to switch off/on the functionality of entire protocol.
    bool    public override protocolPaused;     // Switch to pause the functionality of the entire protocol.
    address public immutable override governor; // The Governor responsible for management of global Helios variables.

    mapping(address => bool) public override isValidPoolDelegate;                   // Mapping of valid Pool Delegates (prevent unauthorized/unknown addresses from creating Pools)
    mapping(address => bool) public override isValidPoolFactory;                    // Mapping of valid Pool Factories
    mapping(address => bool) public override isValidLiquidityAsset;                 // Mapping of valid Liquidity Assets
    mapping(address => mapping(address => bool)) public override validSubFactories;

    event ProtocolPaused(bool pause);
    event Initialized();
    event GlobalAdminSet(address indexed newGlobalAdmin);
    event PoolDelegateSet(address indexed delegate, bool valid);
    event LiquidityAssetSet(address asset, uint256 decimals, string symbol, bool valid);

    // Checks that `msg.sender` is the Governor
    modifier isGovernor() {
        require(msg.sender == governor, "MG:NOT_GOV");
        _;
    }

    constructor(address _governor, address _globalAdmin) {
        require(_governor != address(0), "HG:ZERO_GOV");
        require(_globalAdmin != address(0), "HG:ZERO_ADM");
        governor = _governor;
        globalAdmin = _globalAdmin;
        emit Initialized();
    }

    // Sets the Global Admin. Only the Governor can call this function
    function setGlobalAdmin(address newGlobalAdmin) external {
        require(msg.sender == governor && newGlobalAdmin != address(0), "HG:NOT_GOV_OR_ADM");
        require(!protocolPaused, "HG:PROTO_PAUSED");
        globalAdmin = newGlobalAdmin;
        emit GlobalAdminSet(newGlobalAdmin);
    }

    // Sets the paused/unpaused state of the protocol. Only the Global Admin can call this function
    function setProtocolPause(bool pause) external {
        require(msg.sender == globalAdmin, "HG:NOT_ADM");
        protocolPaused = pause;
        emit ProtocolPaused(pause);
    }

    // Sets the validity of a PoolFactory. Only the Governor can call this function
    function setValidPoolFactory(address poolFactory, bool valid) external isGovernor {
        isValidPoolFactory[poolFactory] = valid;
    }

    // Sets the validity of a Pool Delegate (those allowed to create Pools). Only the Governor can call this function
    function setPoolDelegateAllowList(address delegate, bool valid) external isGovernor {
        isValidPoolDelegate[delegate] = valid;
        emit PoolDelegateSet(delegate, valid);
    }

    // Sets the validity of a sub factory as it relates to a super factory. Only the Governor can call this function
    function setValidSubFactory(address superFactory, address subFactory, bool valid) external isGovernor {
        require(isValidPoolFactory[superFactory], "HG:INV_SUPER_F");
        validSubFactories[superFactory][subFactory] = valid;
    }

    // Sets the validity of an asset for liquidity in Pools. Only the Governor can call this function
    function setLiquidityAsset(address asset, bool valid) external isGovernor {
        isValidLiquidityAsset[asset] = valid;
        emit LiquidityAssetSet(asset, IERC20Metadata(asset).decimals(), IERC20Metadata(asset).symbol(), valid);
    }

    // Checks that a subFactory is valid as it relates to a super factory
    function isValidSubFactory(address superFactory, address subFactory, uint8 factoryType) external view returns (bool) {
        return validSubFactories[superFactory][subFactory] && ISubFactory(subFactory).factoryType() == factoryType;
    }
}
