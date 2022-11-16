// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "./interfaces/IPool.sol";
import "./interfaces/IPoolFactory.sol";
import {IHeliosGlobals as IHeliosGlobalsLike} from "./interfaces/IHeliosGlobals.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Pool is IPool, ERC20 {

    address public immutable superFactory;
    address public immutable poolDelegate;

    uint256 public immutable lockupPeriod;
    uint256 public immutable apy;
    uint256 public immutable maxInvestmentSize;
    uint256 public immutable minInvestmentSize;

    bool public openToPublic;

    State public poolState;

    mapping(address => bool) public poolAdmins;

    constructor(
        address _poolDelegate,
        uint256 _lockupPeriod,
        uint256 _apy,
        uint256 _maxInvestmentSize,
        uint256 _minInvestmentSize,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol){
        poolDelegate = _poolDelegate;
        superFactory = msg.sender;
        lockupPeriod = _lockupPeriod;
        apy = _apy;
        maxInvestmentSize = _maxInvestmentSize;
        minInvestmentSize = _minInvestmentSize;

        emit PoolStateChanged(State.Initialized);
    }

    function setPoolAdmin(address poolAdmin, bool allowed) external {
        _isValidDelegateAndProtocolNotPaused();
        poolAdmins[poolAdmin] = allowed;
        emit PoolAdminSet(poolAdmin, allowed);
    }

    /**
        @dev Checks that `msg.sender` is the Pool Delegate.
     */
    function _isValidDelegate() internal view {
        require(msg.sender == poolDelegate, "P:NOT_DEL");
    }

    /**
        @dev Checks that `msg.sender` is the Pool Delegate or a Pool Admin.
     */
    function _isValidDelegateOrPoolAdmin() internal view {
        require(msg.sender == poolDelegate || poolAdmins[msg.sender], "P:NOT_DEL_OR_ADMIN");
    }

    /**
        @dev Checks that `msg.sender` is the Pool Delegate and that the protocol is not in a paused state.
     */
    function _isValidDelegateAndProtocolNotPaused() internal view {
        _isValidDelegate();
        _whenProtocolNotPaused();
    }

    /**
        @dev Checks that the protocol is not in a paused state.
     */
    function _whenProtocolNotPaused() internal view {
        require(!_globals(superFactory).protocolPaused(), "P:PROTO_PAUSED");
    }

    /**
        @dev Returns the HeliosGlobals instance.
     */
    function _globals(address poolFactory) internal view returns (IHeliosGlobalsLike) {
        return IHeliosGlobalsLike(IPoolFactory(poolFactory).globals());
    }
}

