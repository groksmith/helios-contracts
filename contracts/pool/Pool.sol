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
    string constant NAME = "Helios Tokenized Pool";
    string constant SYMBOL = "HLS-P";

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
    event TotalCustodyAllowanceUpdated(address indexed liquidityProvider, uint256 newTotalAllowance);

    mapping(address => bool)        public poolAdmins;
    mapping(address => uint256)     public depositDate;
    mapping(address => uint256)     public totalCustodyAllowance;
    mapping(address => mapping(address => uint256)) public custodyAllowance;

    constructor(
        address _poolDelegate,
        address _liquidityAsset,
        address _llFactory,
        uint256 _lockupPeriod,
        uint256 _apy,
        uint256 _duration,
        uint256 _investmentPoolSize,
        uint256 _minInvestmentAmount
    ) PoolFDT(NAME, SYMBOL){
        require(_liquidityAsset != address(0), "P:ZERO_LIQUIDITY_ASSET");
        require(_poolDelegate != address(0), "P:ZERO_POOL_DELEGATE");
        require(_llFactory != address(0), "P:ZERO_LIQUIDITY_LOCKER_FACTORY");

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

        _isValidLiquidityAsset(_liquidityAsset);

        liquidityLocker = address(ILiquidityLockerFactory(_llFactory).newLocker(_liquidityAsset));

        emit PoolStateChanged(poolState);
    }

    function finalize() external {
        _isValidDelegateAndProtocolNotPaused();
        _isValidState(State.Initialized);
        poolState = State.Finalized;
        emit PoolStateChanged(poolState);
        openToPublic = true;
        emit PoolOpenedToPublic(openToPublic);
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

    function deposit(uint256 amt) external nonReentrant {
        require(amt > 0, "P:NEGATIVE_DEPOSIT");
        require(openToPublic, "P:POOL_NOT_OPEN");
        require(_balanceOfLiquidityLocker().add(amt) <= investmentPoolSize, "P:DEPOSIT_AMT_EXCEEDS_POOL_SIZE");
        require(_balanceOfLiquidityLocker().add(amt) >= minInvestmentAmount, "P:DEPOSIT_AMT_BELOW_MIN");

        _whenProtocolNotPaused();
        _isValidState(State.Finalized);

        uint256 wad = _toWad(amt);
        PoolLib.updateDepositDate(depositDate, balanceOf(msg.sender), wad, msg.sender);

        liquidityAsset.safeTransferFrom(msg.sender, liquidityLocker, amt);
        _mint(msg.sender, wad);

        _emitBalanceUpdatedEvent();
        emit CoolDown(msg.sender, uint256(0));
    }

    function withdraw(uint256 amt) external nonReentrant {
        _whenProtocolNotPaused();
        uint256 wad = _toWad(amt);
        _canWithdraw(msg.sender, wad);

        _burn(msg.sender, wad);  // Burn the corresponding PoolFDTs balance.
        withdrawFunds();         // Transfer full entitled interest, decrement `interestSum`.

        // Transfer amount that is due after realized losses are accounted for.
        // Recognized losses are absorbed by the LP.
        _transferLiquidityLockerFunds(msg.sender, amt.sub(_recognizeLosses()));

        _emitBalanceUpdatedEvent();
    }

    function withdrawFunds() public override{
        _whenProtocolNotPaused();
        uint256 withdrawableFunds = _prepareWithdraw();

        if (withdrawableFunds == uint256(0)) return;

        _transferLiquidityLockerFunds(msg.sender, withdrawableFunds);
        _emitBalanceUpdatedEvent();

        interestSum = interestSum.sub(withdrawableFunds);

        _updateFundsTokenBalance();
    }

    function increaseCustodyAllowance(address custodian, uint256 amount) external {
        uint256 oldAllowance      = custodyAllowance[msg.sender][custodian];
        uint256 newAllowance      = oldAllowance.add(amount);
        uint256 newTotalAllowance = totalCustodyAllowance[msg.sender].add(amount);

        PoolLib.increaseCustodyAllowanceChecks(custodian, amount, newTotalAllowance, balanceOf(msg.sender));

        custodyAllowance[msg.sender][custodian] = newAllowance;
        totalCustodyAllowance[msg.sender]       = newTotalAllowance;
        emit CustodyAllowanceChanged(msg.sender, custodian, oldAllowance, newAllowance);
        emit TotalCustodyAllowanceUpdated(msg.sender, newTotalAllowance);
    }

    function transferByCustodian(address from, address to, uint256 amount) external nonReentrant {
        uint256 oldAllowance = custodyAllowance[from][msg.sender];
        uint256 newAllowance = oldAllowance.sub(amount);

        PoolLib.transferByCustodianChecks(from, to, amount);

        custodyAllowance[from][msg.sender] = newAllowance;
        uint256 newTotalAllowance          = totalCustodyAllowance[from].sub(amount);
        totalCustodyAllowance[from]        = newTotalAllowance;
        emit CustodyTransfer(msg.sender, from, to, amount);
        emit CustodyAllowanceChanged(from, msg.sender, oldAllowance, newAllowance);
        emit TotalCustodyAllowanceUpdated(msg.sender, newTotalAllowance);
    }

    function setPoolAdmin(address poolAdmin, bool allowed) external {
        _isValidDelegateAndProtocolNotPaused();
        poolAdmins[poolAdmin] = allowed;
        emit PoolAdminSet(poolAdmin, allowed);
    }

    function isDepositAllowed(uint256 depositAmt) public view returns (bool) {
        require(depositAmt > 0, "P:NEGATIVE_DEPOSIT");
        require(openToPublic, "P:POOL_NOT_OPEN");
        require(_balanceOfLiquidityLocker().add(depositAmt) <= investmentPoolSize, "P:DEPOSIT_AMT_EXCEEDS_POOL_SIZE");
        require(_balanceOfLiquidityLocker().add(depositAmt) >= minInvestmentAmount, "P:DEPOSIT_AMT_BELOW_MIN");

        return true;
    }

    function _canWithdraw(address account, uint256 wad) internal view {
        require(depositDate[account].add(lockupPeriod) <= block.timestamp, "P:FUNDS_LOCKED");
        require(balanceOf(account).sub(wad) >= totalCustodyAllowance[account], "P:INSUFFICIENT_TRANS_BAL");
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

    function _globals(address poolFactory) internal view returns (IHeliosGlobals) {
        return IHeliosGlobals(PoolFactory(poolFactory).globals());
    }

    function _emitBalanceUpdatedEvent() internal {
        emit BalanceUpdated(liquidityLocker, address(liquidityAsset), _balanceOfLiquidityLocker());
    }

    function _transferLiquidityAsset(address to, uint256 value) internal {
        liquidityAsset.safeTransfer(to, value);
    }

    function _whenProtocolNotPaused() internal view {
        require(!_globals(superFactory).protocolPaused(), "P:PROTO_PAUSED");
    }

    function _isValidLiquidityAsset(address _liquidityAsset) internal view {
        require(_globals(superFactory).isValidLiquidityAsset(_liquidityAsset), "P:INVALID_LIQ_ASSET");
    }

    function _isValidDelegateAndProtocolNotPaused() internal view {
        _isValidDelegate();
        _whenProtocolNotPaused();
    }

    function _transferLiquidityLockerFunds(address to, uint256 value) internal returns (bool){
        return ILiquidityLocker(liquidityLocker).transfer(to, value);
    }
}