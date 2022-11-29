// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../global/HeliosGlobals.sol";
import "./PoolFactory.sol";

contract Pool is ERC20 {
    address public immutable superFactory;
    address public poolDelegate;
    uint256 public lockupPeriod;
    uint256 public apy;
    uint256 public maxInvestmentSize;
    uint256 public minInvestmentSize;

    enum State {Initialized, Finalized, Deactivated}
    State public poolState;

    event PoolStateChanged(State state);
    event PoolAdminSet(address indexed poolAdmin, bool allowed);

    mapping(address => bool)public poolAdmins;

    constructor(
        address _poolDelegate,
        uint256 _lockupPeriod,
        uint256 _apy,
        uint256 _maxInvestmentSize,
        uint256 _minInvestmentSize,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol){
        superFactory = msg.sender;
        poolDelegate = _poolDelegate;
        lockupPeriod = _lockupPeriod;
        apy = _apy;
        maxInvestmentSize = _maxInvestmentSize;
        minInvestmentSize = _minInvestmentSize;
        poolState = State.Initialized;
        emit PoolStateChanged(poolState);
    }

    function finalize() external {
        _isValidDelegateAndProtocolNotPaused();
        _isValidState(State.Initialized);
        poolState = State.Finalized;
        emit PoolStateChanged(poolState);
    }

    function deactivate() external {
        _isValidDelegateAndProtocolNotPaused();
        _isValidState(State.Finalized);
        poolState = State.Deactivated;
        emit PoolStateChanged(poolState);
    }

    function setPoolAdmin(address poolAdmin, bool allowed) external {
        _isValidDelegateAndProtocolNotPaused();
        poolAdmins[poolAdmin] = allowed;
        emit PoolAdminSet(poolAdmin, allowed);
    }

    function _isValidState(State _state) internal view {
        require(poolState == _state, "P:BAD_STATE");
    }

    function _isValidDelegate() internal view {
        require(msg.sender == poolDelegate, "P:NOT_DEL");
    }

    function _globals(address poolFactory) internal view returns (HeliosGlobals) {
        return HeliosGlobals(PoolFactory(poolFactory).globals());
    }

    function _isValidDelegateOrPoolAdmin() internal view {
        require(msg.sender == poolDelegate || poolAdmins[msg.sender], "P:NOT_DEL_OR_ADMIN");
    }

    function _whenProtocolNotPaused() internal view {
        require(!_globals(superFactory).protocolPaused(), "P:PROTO_PAUSED");
    }

    function _isValidDelegateAndProtocolNotPaused() internal view {
        _isValidDelegate();
        _whenProtocolNotPaused();
    }
}