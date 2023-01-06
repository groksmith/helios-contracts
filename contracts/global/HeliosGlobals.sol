// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../interfaces/ISubFactory.sol";

contract HeliosGlobals {
    address public globalAdmin;
    address public governor;
    bool    public protocolPaused;

    mapping(address => bool) public isValidPoolDelegate;
    mapping(address => bool) public isValidPoolFactory;
    mapping(address => bool) public isValidLiquidityAsset;
    mapping(address => mapping(address => bool)) public validSubFactories;

    event ProtocolPaused(bool pause);
    event Initialized();
    event GlobalAdminSet(address indexed newGlobalAdmin);
    event PoolDelegateSet(address indexed delegate, bool valid);
    event LiquidityAssetSet(address asset, uint256 decimals, string symbol, bool valid);

    modifier isGovernor() {
        require(msg.sender == governor, "MG:NOT_GOV");
        _;
    }

    constructor(address _governor, address _globalAdmin) {
        governor = _governor;
        globalAdmin = _globalAdmin;
        emit Initialized();
    }

    function setGlobalAdmin(address newGlobalAdmin) external {
        require(msg.sender == governor && newGlobalAdmin != address(0), "HG:NOT_GOV_OR_ADMIN");
        require(!protocolPaused, "HG:PROTO_PAUSED");
        globalAdmin = newGlobalAdmin;
        emit GlobalAdminSet(newGlobalAdmin);
    }

    function setProtocolPause(bool pause) external {
        require(msg.sender == globalAdmin, "HG:NOT_ADMIN");
        protocolPaused = pause;
        emit ProtocolPaused(pause);
    }

    function setValidPoolFactory(address poolFactory, bool valid) external isGovernor {
        isValidPoolFactory[poolFactory] = valid;
    }

    function setPoolDelegateAllowList(address delegate, bool valid) external isGovernor {
        isValidPoolDelegate[delegate] = valid;
        emit PoolDelegateSet(delegate, valid);
    }

    function setValidSubFactory(address superFactory, address subFactory, bool valid) external isGovernor {
        require(isValidPoolFactory[superFactory], "HG:INVALID_SUPER_F");
        validSubFactories[superFactory][subFactory] = valid;
    }

    function setLiquidityAsset(address asset, bool valid) external isGovernor {
        isValidLiquidityAsset[asset] = valid;
        emit LiquidityAssetSet(asset, IERC20Metadata(asset).decimals(), IERC20Metadata(asset).symbol(), valid);
    }

    function isValidSubFactory(address superFactory, address subFactory, uint8 factoryType) external view returns (bool) {
        return validSubFactories[superFactory][subFactory] && ISubFactory(subFactory).factoryType() == factoryType;
    }
}
