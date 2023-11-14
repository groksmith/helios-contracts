// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "../interfaces/IPoolFactory.sol";
import "../interfaces/IHeliosGlobals.sol";
import "../library/PoolLib.sol";
import "../token/PoolFDT.sol";

import "hardhat/console.sol";

// Pool maintains all accounting and functionality related to Pools
contract Pool is PoolFDT {
    using SafeMath for uint256;
    using SafeMathUint for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    address public immutable superFactory; // The factory that deployed this Pool
    address public immutable poolDelegate; // The Pool Delegate address, maintains full authority over the Pool
    uint256 private immutable liquidityAssetDecimals; // The precision for the Liquidity Asset (i.e. `decimals()`)

    uint256 public principalOut; // The sum of all outstanding principal on Loans.
    address public borrower; // Address of borrower for this Pool.
    address public blendedPool; // Address of borrower for this Pool.
    address public liquidityLocker; // Address of the liquidityLocker

    struct PoolInfo {
        uint256 lockupPeriod;
        uint256 apy;
        uint256 duration;
        uint256 investmentPoolSize;
        uint256 minInvestmentAmount;
    }

    PoolInfo public poolInfo;

    enum State {
        Initialized,
        Finalized,
        Deactivated
    }
    State public poolState;

    event PoolStateChanged(State state);
    event PoolAdminSet(address indexed poolAdmin, bool allowed);
    event BorrowerSet(address indexed borrower);
    event BalanceUpdated(
        address indexed liquidityProvider,
        address indexed token,
        uint256 balance
    );
    event Deposit(address indexed investor, uint256 amount);
    event Drawdown(
        address indexed borrower,
        uint256 amount,
        uint256 principalOut
    );
    event Payment(
        address indexed borrower,
        uint256 amount,
        uint256 principalOut
    );

    mapping(address => bool) public poolAdmins; // The Pool Admin addresses that have permission to do certain operations in case of disaster management
    mapping(address => uint256) public depositDate; // Used for deposit/withdraw logic

    constructor(
        address _poolDelegate,
        address _liquidityAsset,
        address _llFactory,
        address _blendedPool,
        uint256 _lockupPeriod,
        uint256 _apy,
        uint256 _duration,
        uint256 _investmentPoolSize,
        uint256 _minInvestmentAmount
    ) PoolFDT(PoolLib.NAME, PoolLib.SYMBOL) {
        require(_liquidityAsset != address(0), "P:ZERO_LIQ_ASSET");
        require(_poolDelegate != address(0), "P:ZERO_POOL_DLG");
        require(_llFactory != address(0), "P:ZERO_LIQ_LOCKER_FACTORY");

        liquidityAsset = IERC20(_liquidityAsset);
        liquidityAssetDecimals = ERC20(_liquidityAsset).decimals();

        superFactory = msg.sender;
        poolDelegate = _poolDelegate;
        blendedPool = _blendedPool;

        poolInfo = PoolInfo(
            _lockupPeriod,
            _apy,
            _duration,
            _investmentPoolSize,
            _minInvestmentAmount
        );

        poolState = State.Initialized;

        require(
            _globals(superFactory).isValidLiquidityAsset(_liquidityAsset),
            "P:INVALID_LIQ_ASSET"
        );

        liquidityLocker = address(
            ILiquidityLockerFactory(_llFactory).newLocker(_liquidityAsset)
        );

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
        require(
            totalMinted + amount <= poolInfo.investmentPoolSize,
            "P:DEP_AMT_EXCEEDS_POOL_SIZE"
        );

        _whenProtocolNotPaused();
        _isValidState(State.Finalized);

        PoolLib.updateDepositDate(
            depositDate,
            balanceOf(msg.sender),
            amount,
            msg.sender
        );
        liquidityAsset.safeTransferFrom(msg.sender, liquidityLocker, amount);

        _mint(msg.sender, amount);

        _emitBalanceUpdatedEvent();
        emit Deposit(msg.sender, amount);
    }

    function canWithdraw(uint256 amount) external view returns (bool) {
        _canWithdraw(msg.sender, amount);
        return true;
    }

    function withdrawableOf(address owner) external view returns (uint256) {
        require(
            depositDate[owner].add(poolInfo.lockupPeriod) <= block.timestamp,
            "P:FUNDS_LOCKED"
        );

        return
            Math.min(
                liquidityAsset.balanceOf(liquidityLocker),
                super.balanceOf(owner)
            );
    }

    function totalDeposited() external view returns (uint256) {
        return totalMinted;
    }

    function withdraw(uint256 amount) external nonReentrant {
        _whenProtocolNotPaused();
        _canWithdraw(msg.sender, amount);

        // Burn the corresponding PoolFDTs balance.
        _burn(msg.sender, amount);

        _transferLiquidityLockerFunds(msg.sender, amount);

        _emitBalanceUpdatedEvent();
    }

    function drawdownAmount() external view returns (uint256) {
        return _drawdownAmount();
    }

    function drawdown(uint256 amount) external isBorrower nonReentrant {
        require(amount > 0, "P:INVALID_AMOUNT");
        require(amount <= _drawdownAmount(), "P:INSUFFICIENT_TOTAL_SUPPLY");

        principalOut = principalOut.add(amount);

        _transferLiquidityLockerFunds(msg.sender, amount);
        emit Drawdown(msg.sender, amount, principalOut);
    }

    //NEW
    function distributePayments(
        uint256 principalClaim
    ) external onlyOwner nonReentrant {
        require(principalClaim > 0, "P:ZERO_CLAIM");
        uint balance = totalSupply();


        if (balance < principalClaim) {
            uint256 amountNeeded = principalClaim - balance;
            blendedPool.requestLiquidityAssets(amountNeeded);
            laOwedToBlendedPool += amountNeeded;
            uint lpAmount = amountNeeded / ORACLE_VALUE; //TODO
            _mint(blendedPool, lpAmount);
            // Handle the blendedPool becoming a holder in this pool
            // This could be by minting LP tokens to blendedPool, or another method
            return;
        }

        // NOTE: HAPPY PATH
        if (principalClaim <= liquidityLocker.assetsAvailable()) {
            for (uint256 i = 0; i < holders.length; i++) {
                address holder = holders[i];
                uint256 holderBalance = balanceOf(holder);
                uint256 holderShare = (totalAmount * holderBalance) /
                    totalSupply;

                require(
                    distributionAsset.transfer(holder, holderShare),
                    "Distribution failed"
                );
            }
            return;
        }

        _transferLiquidityAssetFrom(
            msg.sender,
            liquidityLocker,
            principalClaim
        );
        updateFundsReceived();

        emit Payment(msg.sender, principalClaim, interestSum);
    }

    function decimals() public view override returns (uint8) {
        return uint8(liquidityAssetDecimals);
    }

    function withdrawFunds() public override whenNotPaused {
        withdrawableDividend = withdrawableFundsOf(msg.sender);
        withdrawFundsAmount(withdrawableDividend);
    }

    function withdrawFundsAmount(uint256 amount) public override whenNotPaused {
        require(
            depositDate[owner].add(poolInfo.lockupPeriod) <= block.timestamp,
            "P:FUNDS_LOCKED"
        );
        require(withdrawableFundsOf(msg.sender) > 0, "P:NOT_INVESTOR");
        uint256 withdrawableFunds = _prepareWithdraw(amount);
        require(
            amount <= withdrawableFunds,
            "P:INSUFFICIENT_WITHDRAWABLE_FUNDS"
        );

        _transferLiquidityLockerFunds(msg.sender, amount);
        _emitBalanceUpdatedEvent();

        interestSum = interestSum.sub(amount);

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
        require(_borrower != address(0), "P:ZERO_BORROWER");

        _isValidDelegateAndProtocolNotPaused();
        borrower = _borrower;
        emit BorrowerSet(borrower);
    }

    function _canWithdraw(address account, uint256 amount) internal view {
        require(
            depositDate[account].add(poolInfo.lockupPeriod) <= block.timestamp,
            "P:FUNDS_LOCKED"
        );
        require(balanceOf(account) >= amount, "P:INSUFFICIENT_BALANCE");
        require(
            amount <= _balanceOfLiquidityLocker(),
            "P:INSUFFICIENT_LIQUIDITY"
        );
    }

    // Get drawdown available amount
    function _drawdownAmount() internal view returns (uint256) {
        return totalSupply() - principalOut;
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
        emit BalanceUpdated(
            liquidityLocker,
            address(liquidityAsset),
            _balanceOfLiquidityLocker()
        );
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
    function _transferLiquidityAssetFrom(
        address from,
        address to,
        uint256 value
    ) internal {
        liquidityAsset.safeTransferFrom(from, to, value);
    }

    // Transfers Liquidity Locker assets to given `to` address
    function _transferLiquidityLockerFunds(
        address to,
        uint256 value
    ) internal returns (bool) {
        return _liquidityLocker().transfer(to, value);
    }

    // TODO: cut
    // // Returns the LiquidityLocker instance
    // function _liquidityLocker() internal view returns (ILiquidityLocker) {
    //     return ILiquidityLocker(liquidityLocker);
    // }

    // Returns the HeliosGlobals instance
    function _globals(
        address poolFactory
    ) internal view returns (IHeliosGlobals) {
        return IHeliosGlobals(IPoolFactory(poolFactory).globals());
    }

    // Checks that `msg.sender` is the Borrower
    modifier isBorrower() {
        require(msg.sender == borrower, "P:NOT_BORROWER");
        _;
    }
}
