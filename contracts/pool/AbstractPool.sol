// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../token/PoolFDT.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../interfaces/ILiquidityLockerFactory.sol";
import "../interfaces/ILiquidityLocker.sol";
import "../library/PoolLib.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract AbstractPool is PoolFDT, Pausable, Ownable {
    using SafeERC20 for IERC20;

    ILiquidityLocker public immutable liquidityLocker; // The LiquidityLocker owned by this contract
    IERC20 public immutable liquidityAsset; // The asset deposited by Lenders into the LiquidityLocker
    uint256 internal immutable liquidityAssetDecimals; // The precision for the Liquidity Asset (i.e. `decimals()`)
    uint256 public principalOut;

    mapping(address => uint256) public lastWithdrawalTime;
    mapping(address => uint256) public lastWithdrawalAmount;
    mapping(address => uint) public rewards;
    mapping(address => uint) public pendingWithdrawals;
    mapping(address => uint) public pendingRewards;
    mapping(address => uint256) public depositDate; // Used for deposit/withdraw logic

    uint256 public withdrawLimit; // Maximum amount that can be withdrawn in a period
    uint256 public withdrawPeriod; // Timeframe for the withdrawal limit

    event Deposit(address indexed investor, uint256 indexed amount);
    event Withdrawal(address indexed investor, uint256 indexed amount);
    event PendingWithdrawal(address indexed investor, uint256 indexed amount);
    event PendingWithdrawalConcluded(
        address indexed investor,
        uint256 indexed amount
    );
    event RewardClaimed(address indexed recipient, uint256 indexed amount);
    event Reinvest(address indexed investor, uint256 indexed amount);
    event PendingReward(address indexed recipient, uint256 indexed amount);
    event PendingRewardConcluded(
        address indexed recipient,
        uint256 indexed amount
    );
    event WithdrawalOverThreshold(
        address indexed caller,
        uint256 indexed amount
    );

    struct PoolInfo {
        uint256 lockupPeriod;
        uint256 apy;
        uint256 duration;
        uint256 investmentPoolSize;
        uint256 minInvestmentAmount;
        uint256 withdrawThreshold;
    }

    PoolInfo public poolInfo;

    constructor(
        address _liquidityAsset,
        address _llFactory,
        string memory tokenName,
        string memory tokenSymbol,
        uint256 _withdrawLimit,
        uint256 _withdrawPeriod
    ) PoolFDT(tokenName, tokenSymbol) {
        liquidityAsset = IERC20(_liquidityAsset);
        liquidityAssetDecimals = ERC20(_liquidityAsset).decimals();
        liquidityLocker = ILiquidityLocker(
            ILiquidityLockerFactory(_llFactory).newLocker(_liquidityAsset)
        );
        withdrawLimit = _withdrawLimit;
        withdrawPeriod = _withdrawPeriod;
    }

    /// @notice the caller becomes an investor. For this to work the caller must set the allowance for this pool's address
    function deposit(uint256 _amount) external whenNotPaused nonReentrant {
        require(_amount >= poolInfo.minInvestmentAmount, "P:DEP_AMT_BELOW_MIN");
        require(
            totalSupply() + _amount <= poolInfo.investmentPoolSize,
            "P:MAX_POOL_SIZE_REACHED"
        );

        //TODO: Tigran Arakelyan - strange logic for updating deposit Date (comes from maple lib, uses weird math)
        PoolLib.updateDepositDate(
            depositDate,
            balanceOf(msg.sender),
            _amount,
            msg.sender
        );
        liquidityAsset.safeTransferFrom(
            msg.sender,
            address(liquidityLocker),
            _amount
        );

        _mint(msg.sender, _amount);

        _emitBalanceUpdatedEvent();
        emit Deposit(msg.sender, _amount);
    }

    /// @notice used to deposit secondary liquidity assets (non-USDT)
    function depositSecondaryAsset(
        uint256 _amount,
        address _assetAddr
    ) external whenNotPaused nonReentrant {
        require(_amount >= poolInfo.minInvestmentAmount, "P:DEP_AMT_BELOW_MIN");
        require(
            totalSupply() + _amount <= poolInfo.investmentPoolSize,
            "P:MAX_POOL_SIZE_REACHED"
        );
        require(liquidityLocker.assetsExists(_assetAddr), "P:UNKNOWN_ASSET");

        //TODO: Tigran Arakelyan - strange logic for updating deposit Date (comes from maple lib, uses weird math)
        PoolLib.updateDepositDate(
            depositDate,
            balanceOf(msg.sender),
            _amount,
            msg.sender
        );
        IERC20(_assetAddr).safeTransferFrom(
            msg.sender,
            address(liquidityLocker),
            _amount
        );

        _mint(msg.sender, _amount);

        _emitBalanceUpdatedEvent();
        emit Deposit(msg.sender, _amount);
    }

    /// @notice withdraws the caller's liquidity assets
    /// @param  _amount the amount of LA to be withdrawn
    function withdraw(uint256 _amount) public whenNotPaused returns (bool) {
        require(balanceOf(msg.sender) >= _amount, "P:INSUFFICIENT_BALANCE");
        require(
            depositDate[msg.sender] + poolInfo.lockupPeriod <= block.timestamp,
            "P:FUNDS_LOCKED"
        );

        // Check if the current withdrawal exceeds the limit in the specified period
        if (block.timestamp < lastWithdrawalTime[msg.sender] + withdrawPeriod) {
            require(
                lastWithdrawalAmount[msg.sender] + _amount <= withdrawLimit,
                "P:WITHDRAW_LIMIT_EXCEEDED"
            );
        } else {
            lastWithdrawalAmount[msg.sender] = 0;
        }

        // Update the withdrawal history
        lastWithdrawalTime[msg.sender] = block.timestamp;
        lastWithdrawalAmount[msg.sender] += _amount;

        /**
         * TODO: Tigran Arakelyan - possible attack vector
         * Investor can withdraw big amount partially and contract will be happy with it
         * Maybe we should check cumulative withdrawals amount
         */
        if (_amount > poolInfo.withdrawThreshold) {
            emit WithdrawalOverThreshold(msg.sender, _amount);
            revert("P:THRESHOLD_REACHED");
        }

        _burn(msg.sender, _amount);

        //unhappy path - the withdrawal is then added in the 'pending' to be processed by the admin
        if (liquidityLocker.totalBalance() < _amount) {
            pendingWithdrawals[msg.sender] += _amount;
            emit PendingWithdrawal(msg.sender, _amount);
            return false;
        }

        _transferLiquidityLockerFunds(msg.sender, _amount);
        _emitBalanceUpdatedEvent();
        emit Withdrawal(msg.sender, _amount);
        return true;
    }

    /// @notice Used to reinvest rewards into more LP tokens
    /// @param  _amount the amount of rewards to be converted into LP
    function reinvest(uint256 _amount) external {
        require(_amount > 0, "P:INVALID_VALUE");
        require(rewards[msg.sender] >= _amount, "P:INSUFFICIENT_BALANCE");

        _mint(msg.sender, rewards[msg.sender]);
        rewards[msg.sender] -= _amount;
        _emitBalanceUpdatedEvent();
        emit Reinvest(msg.sender, _amount);
    }

    /// @notice Used to distribute rewards among investors (LP token holders)
    /// @param  _amount the amount to be divided among investors
    /// @param  _holders the list of investors must be provided externally due to Solidity limitations
    function distributeRewards(
        uint256 _amount,
        address[] calldata _holders
    ) external onlyOwner nonReentrant {
        require(_amount > 0, "P:INVALID_VALUE");
        require(_holders.length > 0, "P:ZERO_HOLDERS");
        for (uint256 i = 0; i < _holders.length; i++) {
            address holder = _holders[i];

            uint256 holderBalance = balanceOf(holder);
            uint256 holderShare = (_amount * holderBalance) / totalSupply();
            rewards[holder] += holderShare;
        }
    }

    /// @notice Admin function used for unhappy path after withdrawal failure
    /// @param _recipient address of the recipient who didn't get the liquidity
    function concludePendingWithdrawal(address _recipient) external onlyOwner {
        uint256 amount = pendingWithdrawals[_recipient];
        require(
            liquidityLocker.transfer(_recipient, amount),
            "P:CONCLUDE_WITHDRAWAL_FAILED"
        );

        //remove from pendingWithdrawals mapping:
        delete pendingWithdrawals[_recipient];
        emit PendingWithdrawalConcluded(_recipient, amount);
    }

    /// @notice Admin function used for unhappy path after reward claiming failure
    /// @param _recipient address of the recipient who didn't get the reward
    function concludePendingReward(address _recipient) external onlyOwner {
        uint256 amount = pendingRewards[_recipient];
        require(
            liquidityLocker.transfer(_recipient, amount),
            "P:CONCLUDE_REWARD_FAILED"
        );

        //remove from pendingWithdrawals mapping:
        delete pendingRewards[_recipient];
        emit PendingRewardConcluded(_recipient, amount);
    }

    /// @notice  Use the pool's money for investment
    function drawdown(address _to) external onlyOwner {
        uint256 amount = _drawdownAmount();
        _transferLiquidityLockerFunds(_to, amount);
    }

    /// @notice  Deposit LA without minimal threshold or getting LP in return
    function adminDeposit(uint _amount) external onlyOwner {
        require(
            liquidityAsset.balanceOf(msg.sender) > _amount,
            "P:NOT_ENOUGH_BALANCE!!"
        );

        liquidityAsset.safeTransferFrom(
            msg.sender,
            address(liquidityLocker),
            _amount
        );
    }

    function getLL() external view returns (address) {
        return address(liquidityLocker);
    }

    function claimReward() external virtual returns (bool);

    /// @notice  Transfers Liquidity Locker assets to given `to` address
    function _transferLiquidityLockerFunds(
        address to,
        uint256 value
    ) internal returns (bool) {
        return liquidityLocker.transfer(to, value);
    }

    // Get drawdown available amount
    function _drawdownAmount() internal view returns (uint256) {
        return totalSupply() - principalOut;
    }

    // Emits a `BalanceUpdated` event for LiquidityLocker
    function _emitBalanceUpdatedEvent() internal {
        emit BalanceUpdated(
            address(liquidityLocker),
            address(liquidityAsset),
            liquidityLocker.totalBalance()
        );
    }
}
