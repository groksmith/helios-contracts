// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../interfaces/IPoolFactory.sol";
import "../interfaces/ILiquidityLockerFactory.sol";
import "../interfaces/ILiquidityLocker.sol";
import "../interfaces/IHeliosGlobals.sol";
import "../library/PoolLib.sol";
import "../token/PoolFDT.sol";

// Pool maintains all accounting and functionality related to Pools
contract Pool is PoolFDT {
    using SafeMath  for uint256;
    using SafeMathUint for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    address public immutable superFactory;              // The factory that deployed this Pool
    address public immutable liquidityLocker;           // The LiquidityLocker owned by this contract
    address public immutable poolDelegate;              // The Pool Delegate address, maintains full authority over the Pool
    IERC20  public immutable liquidityAsset;            // The asset deposited by Lenders into the LiquidityLocker
    uint256 private immutable liquidityAssetDecimals;   // The precision for the Liquidity Asset (i.e. `decimals()`)

    uint256 public principalOut;                        // The sum of all outstanding principal on Loans.
    address public borrower;                            // Address of borrower for this Pool.

    struct PoolInfo {
        uint256 lockupPeriod;
        uint256 apy;
        uint256 duration;
        uint256 investmentPoolSize;
        uint256 minInvestmentAmount;
    }
    PoolInfo public poolInfo;

    enum State {Initialized, Finalized, Deactivated}
    State public poolState;

    event PoolStateChanged(State state);
    event PoolAdminSet(address indexed poolAdmin, bool allowed);
    event BalanceUpdated(address indexed liquidityProvider, address indexed token, uint256 balance);
    event CoolDown(address indexed liquidityProvider, uint256 cooldown);
    event BorrowerSet(address indexed borrower);

    mapping(address => bool)    public poolAdmins;  // The Pool Admin addresses that have permission to do certain operations in case of disaster management
    mapping(address => uint256) public depositDate; // Used for deposit/withdraw logic

    constructor(
        address _poolDelegate,
        address _liquidityAsset,
        address _llFactory,
        uint256 _lockupPeriod,
        uint256 _apy,
        uint256 _duration,
        uint256 _investmentPoolSize,
        uint256 _minInvestmentAmount
    ) PoolFDT(PoolLib.NAME, PoolLib.SYMBOL){
        require(_liquidityAsset != address(0), "P:ZERO_LIQ_ASSET");
        require(_poolDelegate != address(0), "P:ZERO_POOL_DLG");
        require(_llFactory != address(0), "P:ZERO_LIQ_LOCKER_FACTORY");

        liquidityAsset = IERC20(_liquidityAsset);
        liquidityAssetDecimals = ERC20(_liquidityAsset).decimals();

        superFactory = msg.sender;
        poolDelegate = _poolDelegate;

        poolInfo = PoolInfo(
            _lockupPeriod,
            _apy,
            _duration,
            _investmentPoolSize,
            _minInvestmentAmount
        );

        poolState = State.Initialized;

        require(_globals(superFactory).isValidLiquidityAsset(_liquidityAsset), "P:INVALID_LIQ_ASSET");

        liquidityLocker = address(ILiquidityLockerFactory(_llFactory).newLocker(_liquidityAsset));

        emit PoolStateChanged(poolState);
    }

    // Finalizes the Pool, enabling deposits. Only the Pool Delegate can call this function
    function finalize() external {
        _isValidDelegateAndProtocolNotPaused();
        _isValidState(State.Initialized);
        poolState = State.Finalized;
        emit PoolStateChanged(poolState);
    }

    // Triggers deactivation, permanently shutting down the Pool. Only the Pool Delegate can call this function
    function deactivate() external {
        _isValidDelegateAndProtocolNotPaused();
        _isValidState(State.Finalized);
        poolState = State.Deactivated;
        emit PoolStateChanged(poolState);
    }

    function deposit(uint256 amount) external nonReentrant {
        require(amount >= poolInfo.minInvestmentAmount, "P:DEP_AMT_BELOW_MIN");
        require(_balanceOfLiquidityLocker().add(amount) <= poolInfo.investmentPoolSize, "P:DEP_AMT_EXCEEDS_POOL_SIZE");

        _whenProtocolNotPaused();
        _isValidState(State.Finalized);

        PoolLib.updateDepositDate(depositDate, balanceOf(msg.sender), amount, msg.sender);
        liquidityAsset.safeTransferFrom(msg.sender, liquidityLocker, amount);

        _mint(msg.sender, amount);

        _emitBalanceUpdatedEvent();
        emit CoolDown(msg.sender, uint256(0));
    }

    function canWithdraw(uint256 amount) external view returns (bool) {
        _canWithdraw(msg.sender, amount);
        return true;
    }

    function withdraw(uint256 amount) external nonReentrant {
        _whenProtocolNotPaused();
        _canWithdraw(msg.sender, amount);

        // Burn the corresponding PoolFDTs balance.
        _burn(msg.sender, amount);

        // Transfer full entitled interest, decrement `interestSum`.
        // We'll turn off auto distribution funds
        // withdrawFunds();

        _transferLiquidityLockerFunds(msg.sender, amount);

        _emitBalanceUpdatedEvent();
    }

    function drawdown(uint256 amount) external isBorrower nonReentrant {
        require(amount <= _balanceOfLiquidityLocker(), "P:INSUFFICIENT_LIQUIDITY");

        principalOut = principalOut.add(amount);

        _transferLiquidityLockerFunds(msg.sender, amount);
    }

    function makePayment(uint256 principalClaim) external isBorrower nonReentrant {
        uint256 interestClaim = 0;

        if (principalClaim <= principalOut) {
            principalOut = principalOut - principalClaim;
        } else {
            // Distribute `principalClaim` overflow as interest to LPs.
            interestClaim = principalClaim - principalOut;

            // Set `principalClaim` to `principalOut` so correct amount gets transferred.
            principalClaim = principalOut;

            // Set `principalOut` to zero to avoid subtraction overflow.
            principalOut = 0;
        }

        interestSum = interestSum.add(interestClaim);

        _transferLiquidityAssetFrom(msg.sender, liquidityLocker, principalClaim.add(interestClaim));
        updateFundsReceived();
    }

    function decimals() public view override returns (uint8) {
        return uint8(liquidityAssetDecimals);
    }

    function withdrawFunds() public override {
        _whenProtocolNotPaused();
        uint256 withdrawableFunds = _prepareWithdraw();

        if (withdrawableFunds == uint256(0)) return;

        _transferLiquidityLockerFunds(msg.sender, withdrawableFunds);
        _emitBalanceUpdatedEvent();

        interestSum = interestSum.sub(withdrawableFunds);

        _updateFundsTokenBalance();
    }

    // Sets a Pool Admin. Only the Pool Delegate can call this function
    function setPoolAdmin(address poolAdmin, bool allowed) external {
        _isValidDelegateAndProtocolNotPaused();
        poolAdmins[poolAdmin] = allowed;
        emit PoolAdminSet(poolAdmin, allowed);
    }

    // Sets a Borrower. Only the Pool Delegate can call this function
    function setBorrower(address _borrower) external {
        require(_borrower != address(0), "HG:ZERO_BORROWER");

        _isValidDelegateAndProtocolNotPaused();
        borrower = _borrower;
        emit BorrowerSet(borrower);
    }

    function _canWithdraw(address account, uint256 amount) internal view {
        require(depositDate[account].add(poolInfo.lockupPeriod) <= block.timestamp, "P:FUNDS_LOCKED");
        require(amount <= _balanceOfLiquidityLocker(), "P:INSUFFICIENT_LIQUIDITY");
    }

    // Get LiquidityLocker balance
    function _balanceOfLiquidityLocker() internal view returns (uint256) {
        return liquidityAsset.balanceOf(liquidityLocker);
    }

    // Checks that the current state of Pool matches the provided state
    function _isValidState(State _state) internal view {
        require(poolState == _state, "P:BAD_STATE");
    }

    // Emits a `BalanceUpdated` event for LiquidityLocker
    function _emitBalanceUpdatedEvent() internal {
        emit BalanceUpdated(liquidityLocker, address(liquidityAsset), _balanceOfLiquidityLocker());
    }

    // Checks that the protocol is not in a paused state
    function _whenProtocolNotPaused() internal view {
        require(!_globals(superFactory).protocolPaused(), "P:PROTO_PAUSED");
    }

    // Checks that `msg.sender` is the Pool Delegate and not paused
    function _isValidDelegateAndProtocolNotPaused() internal view {
        require(msg.sender == poolDelegate, "P:NOT_DEL");
        _whenProtocolNotPaused();
    }

    // Transfers Liquidity Asset to given `to` address
    function _transferLiquidityAssetFrom(address from, address to, uint256 value) internal {
        liquidityAsset.safeTransferFrom(from, to, value);
    }

    // Transfers Liquidity Locker assets to given `to` address
    function _transferLiquidityLockerFunds(address to, uint256 value) internal returns (bool){
        return _liquidityLocker().transfer(to, value);
    }

    // Returns the LiquidityLocker instance
    function _liquidityLocker() internal view returns (ILiquidityLocker) {
        return ILiquidityLocker(liquidityLocker);
    }

    // Returns the HeliosGlobals instance
    function _globals(address poolFactory) internal view returns (IHeliosGlobals) {
        return IHeliosGlobals(IPoolFactory(poolFactory).globals());
    }

    // Checks that `msg.sender` is the Borrower
    modifier isBorrower() {
        require(msg.sender == borrower, "P:NOT_BORROWER");
        _;
    }
}