// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import "./Pool.sol";
import "../Global/HeliosGlobals.sol";

contract PoolFactory is Pausable {
    uint256  public poolsCreated;
    HeliosGlobals public globals;

    mapping(uint256 => address) public pools;              // Map to reference Pools corresponding to their respective indices.
    mapping(address => bool)    public isPool;             // True only if a Pool was instantiated by this factory.
    mapping(address => bool)    public poolFactoryAdmins;  // The PoolFactory Admin addresses that have permission to do certain operations in case of disaster management.

    event PoolFactoryAdminSet(address indexed poolFactoryAdmin, bool allowed);

    event PoolCreated(address indexed pool, address indexed delegate, string name, string symbol);

    constructor(address _globals) {
        globals = HeliosGlobals(_globals);
    }

    function setGlobals(address newGlobals) external {
        _isValidGovernor();
        globals = HeliosGlobals(newGlobals);
    }

    function createPool(
        uint256 lockupPeriod,
        uint256 apy,
        uint256 maxInvestmentSize,
        uint256 minInvestmentSize
    ) external whenNotPaused returns (address poolAddress) {
        _whenProtocolNotPaused();
        {
            HeliosGlobals _globals = globals;
            require(_globals.isValidPoolDelegate(msg.sender), "PF:NOT_DELEGATE");
        }

        string memory name = "Helios Pool Token";
        string memory symbol = "HLS-LP";

        Pool pool = new Pool(
            msg.sender,
            lockupPeriod,
            apy,
            maxInvestmentSize,
            minInvestmentSize,
            name,
            symbol
        );

        poolAddress = address(pool);
        pools[poolsCreated] = poolAddress;
        isPool[poolAddress] = true;
        ++poolsCreated;

        emit PoolCreated(
            poolAddress,
            msg.sender,
            name,
            symbol
        );
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

    function _isValidGovernor() internal view {
        require(msg.sender == globals.governor(), "PF:NOT_GOV");
    }

    function _isValidGovernorOrPoolFactoryAdmin() internal view {
        require(msg.sender == globals.governor() || poolFactoryAdmins[msg.sender], "PF:NOT_GOV_OR_ADMIN");
    }

    function _whenProtocolNotPaused() internal view {
        require(!globals.protocolPaused(), "PF:PROTO_PAUSED");
    }
}
