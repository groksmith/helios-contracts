// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import {IHeliosGlobals as IHeliosGlobalsLike} from "./interfaces/IHeliosGlobals.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {IPoolFactory} from "./interfaces/IPoolFactory.sol";
import "./Pool.sol";

contract PoolFactory is IPoolFactory, Pausable {

    uint256 public poolsCreated;
    address public globals;

    mapping(uint256 => address) public pools;
    mapping(address => bool)    public isPool;             // True only if a Pool was instantiated by this factory.
    mapping(address => bool)    public poolFactoryAdmins;

    constructor(address _globals) {
        globals = _globals;
    }

    function setGlobals(address newGlobals) external {
        _isValidGovernor();
        globals = newGlobals;
    }

    function createPool(
        uint256 lockupPeriod,
        uint256 apy,
        uint256 maxInvestmentSize,
        uint256 minInvestmentSize)
    external whenNotPaused returns (address poolAddress) {
        _whenProtocolNotPaused();
        {
            IHeliosGlobalsLike _globals = IHeliosGlobalsLike(globals);
            require(_globals.isValidPoolDelegate(msg.sender), "PF:NOT_DELEGATE");
        }

        string memory name = "Helios Pool Token";
        string memory symbol = "HLS-LP";

        Pool pool = new Pool(msg.sender, lockupPeriod, apy, maxInvestmentSize, minInvestmentSize, name, symbol);

        poolAddress = address(pool);
        pools[poolsCreated] = poolAddress;
        isPool[poolAddress] = true;
        ++poolsCreated;

        emit PoolCreated(poolAddress, msg.sender, name, symbol);
    }

    function setPoolFactoryAdmin(address poolFactoryAdmin, bool allowed) external {
        _isValidGovernor();
        poolFactoryAdmins[poolFactoryAdmin] = allowed;
        emit PoolFactoryAdminSet(poolFactoryAdmin, allowed);
    }

    function pause() external {
        _isValidGovernorOrPoolFactoryAdmin();
        super._pause();
    }

    function unpause() external {
        _isValidGovernorOrPoolFactoryAdmin();
        super._unpause();
    }

    function _whenProtocolNotPaused() internal view {
        require(!IHeliosGlobalsLike(globals).protocolPaused(), "PF:PROTO_PAUSED");
    }

    function _isValidGovernor() internal view {
        require(msg.sender == IHeliosGlobalsLike(globals).governor(), "PF:NOT_GOV");
    }

    function _isValidGovernorOrPoolFactoryAdmin() internal view {
        require(msg.sender == IHeliosGlobalsLike(globals).governor() || poolFactoryAdmins[msg.sender], "PF:NOT_GOV_OR_ADMIN");
    }
}
