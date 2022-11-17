// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

contract HeliosGlobals {
    address public globalAdmin;
    address public governor;
    bool    public protocolPaused;

    mapping(address => bool) public isValidPoolDelegate;
    mapping(address => bool) public isValidPoolFactory;

    event ProtocolPaused(bool pause);
    event Initialized();
    event GlobalAdminSet(address indexed newGlobalAdmin);
    event PoolDelegateSet(address indexed delegate, bool valid);

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
}
