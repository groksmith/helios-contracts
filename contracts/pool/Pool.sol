// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./PoolFactory.sol";
import "./LiquidityLockerFactory.sol";
import "../global/HeliosGlobals.sol";
import "../library/PoolLib.sol";
import "../token/PoolFDT.sol";

contract Pool is PoolFDT {
    using SafeMath  for uint256;
    using SafeERC20 for IERC20;
    uint256 constant WAD = 10 ** 18;

    using SafeMath for uint256;
    using SafeCast for uint256;

    address public immutable superFactory;
    address public immutable liquidityLocker;
    address public poolDelegate;
    IERC20  public immutable liquidityAsset;
    uint256 private immutable liquidityAssetDecimals;

    uint256 public lockupPeriod;
    uint256 public apy;
    uint256 public duration;
    uint256 public investmentPoolSize;
    uint256 public minInvestmentAmount;
    bool public openToPublic;

    enum State {Initialized, Finalized, Deactivated}
    State public poolState;

    event PoolStateChanged(State state);
    event PoolAdminSet(address indexed poolAdmin, bool allowed);
    event PoolOpenedToPublic(bool isOpen);

    event BalanceUpdated(address indexed liquidityProvider, address indexed token, uint256 balance);
    event CustodyTransfer(address indexed custodian, address indexed from, address indexed to, uint256 amount);
    event CustodyAllowanceChanged(address indexed liquidityProvider, address indexed custodian, uint256 oldAllowance, uint256 newAllowance);
    event CoolDown(address indexed liquidityProvider, uint256 cooldown);
    event DepositDateUpdated(address indexed liquidityProvider, uint256 depositDate);

    mapping(address => bool)        public poolAdmins;
    mapping(address => uint256)     public depositDate;

    constructor(
        address _poolDelegate,
        address _liquidityAsset,
        address _llFactory,
        uint256 _lockupPeriod,
        uint256 _apy,
        uint256 _duration,
        uint256 _investmentPoolSize,
        uint256 _minInvestmentAmount,
        string memory name,
        string memory symbol
    ) PoolFDT(name, symbol){
        liquidityAsset = IERC20(_liquidityAsset);
        liquidityAssetDecimals = ERC20(_liquidityAsset).decimals();

        superFactory = msg.sender;
        poolDelegate = _poolDelegate;
        lockupPeriod = _lockupPeriod;
        apy = _apy;
        duration = _duration;
        investmentPoolSize = _investmentPoolSize;
        minInvestmentAmount = _minInvestmentAmount;
        poolState = State.Initialized;

        liquidityLocker = address(LiquidityLockerFactory(_llFactory).newLocker(_liquidityAsset));

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

    function setOpenToPublic(bool open) external {
        _isValidDelegateAndProtocolNotPaused();
        openToPublic = open;
        emit PoolOpenedToPublic(open);
    }

    function deposit(uint256 amt) external {
        _whenProtocolNotPaused();
        _isValidState(State.Finalized);
        require(isDepositAllowed(amt), "P:DEP_NOT_ALLOWED");

        uint256 wad = _toWad(amt);
        PoolLib.updateDepositDate(depositDate, balanceOf(msg.sender), wad, msg.sender);

        liquidityAsset.safeTransferFrom(msg.sender, liquidityLocker, amt);
        _mint(msg.sender, wad);

        _emitBalanceUpdatedEvent();
        emit CoolDown(msg.sender, uint256(0));
    }

    function setPoolAdmin(address poolAdmin, bool allowed) external {
        _isValidDelegateAndProtocolNotPaused();
        poolAdmins[poolAdmin] = allowed;
        emit PoolAdminSet(poolAdmin, allowed);
    }

    function isDepositAllowed(uint256 depositAmt) public view returns (bool) {
        return (openToPublic) &&
        _balanceOfLiquidityLocker().add(depositAmt) <= investmentPoolSize;
    }

    function _toWad(uint256 amt) internal view returns (uint256) {
        return amt.mul(WAD).div(10 ** liquidityAssetDecimals);
    }

    function _balanceOfLiquidityLocker() internal view returns (uint256) {
        return liquidityAsset.balanceOf(liquidityLocker);
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

    function _emitBalanceUpdatedEvent() internal {
        emit BalanceUpdated(liquidityLocker, address(liquidityAsset), _balanceOfLiquidityLocker());
    }

    function _transferLiquidityAsset(address to, uint256 value) internal {
        liquidityAsset.safeTransfer(to, value);
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