// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title PrizePot Token Contract
 * @dev ERC20 Token with advanced features including fees, anti-whale, vesting, and referral system.
 */

// =========================
// Context Contract
// =========================

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

// =========================
// IERC20 Interface
// =========================

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address ownerAddr, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    
    // ERC20 Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed ownerAddr, address indexed spender, uint256 value);
}

// =========================
// Ownable Contract
// =========================

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Renounces ownership of the contract. Leaves the contract without an owner.
     */
    function waiveOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// =========================
// ReentrancyGuard Contract
// =========================

contract ReentrancyGuard {
    uint256 private _status;

    constructor () {
        _status = 1; // NOT_ENTERED
    }

    modifier nonReentrant() {
        require(_status != 2, "ReentrancyGuard: reentrant call");

        _status = 2; // ENTERED

        _;

        _status = 1; // NOT_ENTERED
    }
}

// =========================
// Pausable Contract
// =========================

contract Pausable is Context, Ownable {
    event Paused(address account);
    event Unpaused(address account);

    bool private _paused;

    constructor () {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     * Can only be called by the owner.
     */
    function pause() public onlyOwner whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     * Can only be called by the owner.
     */
    function unpause() public onlyOwner whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// =========================
// PrizePot Contract
// =========================

contract PrizePot is Context, IERC20, Ownable, ReentrancyGuard, Pausable {
    // =========================
    // State Variables
    // =========================

    // Token Details
    string private _name = "Prize Pot";
    string private _symbol = "PPOT";
    uint8 private _decimals = 9;
    uint256 private _totalSupply = 1_000_000_000_000 * (10 ** uint256(_decimals)); // 1 Trillion Tokens

    // Balances and Allowances
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // Fee Exemptions
    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isWalletLimitExempt;
    mapping(address => bool) public isTxLimitExempt;

    // Referral System
    mapping(address => address) public referrer;

    // Anti-Whale Mechanism
    uint256 public whaleThreshold;
    uint256 public higherTaxRate = 15; // 15%
    uint256 public whaleCooldown = 1 hours;
    mapping(address => uint256) private lastWhaleTradeTime;

    // Transaction Limits
    uint256 public maxTxAmount = 10_000_000_000 * (10 ** uint256(_decimals)); // 1% of total supply
    uint256 public walletMax = 20_000_000_000 * (10 ** uint256(_decimals)); // 2% of total supply
    uint256 private minimumTokensBeforeSwap = 500_000_000 * (10 ** uint256(_decimals)); // 0.05% of total supply

    // Fees and Shares
    uint256 public buyLiquidityFee = 2;
    uint256 public buyMarketingFee = 2;
    uint256 public buyTeamFee = 2;
    uint256 public buyDonationFee = 1;

    uint256 public sellLiquidityFee = 3;
    uint256 public sellMarketingFee = 2;
    uint256 public sellTeamFee = 3;
    uint256 public sellDonationFee = 1;

    uint256 public totalLiquidityShare = 4;
    uint256 public totalMarketingShare = 2;
    uint256 public totalTeamShare = 3;
    uint256 public totalDonationShare = 1;

    uint256 public totalTaxIfBuying;
    uint256 public totalTaxIfSelling;
    uint256 public totalDistributionShares;

    // Gas Price and Transaction Cooldown
    uint256 public maxGasPrice = 100 gwei;
    uint256 public txCooldownTime = 60; // 60 seconds

    // Wallet Addresses for Distribution
    address payable public marketingWallet = payable(0x666eda6bD98e24EaF8bcA9D1DD46617ECd61E5b2);
    address payable public teamWallet = payable(0x0de504d353375A999d2d983eC37Ed6FFd186CbA1);
    address payable public liquidityWallet = payable(0x8aF9D64eF4Eea9806FD191a33493b238B90A4d86);
    address payable public donationWallet = payable(0xf1214dBF1D1285D293604601154327A78580E6A4);
    address public immutable deadAddress = 0x000000000000000000000000000000000000dEaD;

    // Swap and Liquify Flags
    bool private inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    bool public checkWalletLimit = true;

    // Vesting Structure
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 amountReleased;
        uint256 releaseTime;
        bool isActive;
    }

    mapping(address => VestingSchedule) public vestingSchedules;

    // Mapping to track last transaction time for anti-bot cooldown
    mapping(address => uint256) private _lastTxTime;

    // Events
    event TokensReleased(address indexed beneficiary, uint256 amountReleased);
    event VestingScheduleSet(address indexed account, uint256 totalAmount, uint256 releaseTime);
    event VestingTokensReleased(address indexed account, uint256 amount);
    event ReferralSet(address indexed user, address indexed referrer);
    // Removed duplicate OwnershipTransferred event

    // =========================
    // Modifiers
    // =========================

    modifier antiBot(address sender) {
        require(block.timestamp - _lastTxTime[sender] >= txCooldownTime, "Cooldown: Please wait before sending again");
        _;
        _lastTxTime[sender] = block.timestamp;
    }

    modifier ensureGasPrice() {
        require(tx.gasprice <= maxGasPrice, "Gas price exceeds limit");
        _;
    }

    // =========================
    // Constructor
    // =========================

    constructor() {
        // Anti-Whale Threshold
        whaleThreshold = _totalSupply / 100; // 1% of total supply

        // Exemptions
        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;

        isWalletLimitExempt[owner()] = true;
        isWalletLimitExempt[address(this)] = true;
        isWalletLimitExempt[deadAddress] = true;

        isTxLimitExempt[owner()] = true;
        isTxLimitExempt[address(this)] = true;

        // Calculate Total Taxes
        totalTaxIfBuying = buyLiquidityFee + buyMarketingFee + buyTeamFee + buyDonationFee;
        totalTaxIfSelling = sellLiquidityFee + sellMarketingFee + sellTeamFee + sellDonationFee;
        totalDistributionShares = totalLiquidityShare + totalMarketingShare + totalTeamShare + totalDonationShare;

        // Assign total supply to the owner
        _balances[_msgSender()] = _totalSupply;
        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    // =========================
    // ERC20 Standard Functions
    // =========================

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address ownerAddr, address spender) public view override returns (uint256) {
        return _allowances[ownerAddr][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     */
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transfer}.
     * Includes anti-whale, fees, and referral reward mechanisms.
     */
    function transfer(address recipient, uint256 amount) public override
        antiBot(_msgSender())
        ensureGasPrice
        nonReentrant
        whenNotPaused
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        rewardReferral(recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     * Includes anti-whale, fees, and referral reward mechanisms.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override
        antiBot(sender)
        ensureGasPrice
        nonReentrant
        whenNotPaused
        returns (bool)
    {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount);
        rewardReferral(recipient, amount);
        return true;
    }

    // =========================
    // Internal Functions
    // =========================

    /**
     * @dev Internal function to transfer tokens, handle fees, and enforce limits.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        // Check transaction limits
        if(!isTxLimitExempt[sender] && !isTxLimitExempt[recipient]) {
            require(amount <= maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
        }

        // Check wallet limits
        if(checkWalletLimit && !isWalletLimitExempt[recipient]) {
            require(_balances[recipient] + amount <= walletMax, "Wallet limit exceeded");
        }

        // Calculate final amount after fees
        uint256 finalAmount = isExcludedFromFee[sender] || isExcludedFromFee[recipient] ? amount : _takeFee(sender, amount);

        // Update balances
        _balances[sender] -= amount;
        _balances[recipient] += finalAmount;

        emit Transfer(sender, recipient, finalAmount);
    }

    /**
     * @dev Internal function to handle fee deduction and distribution.
     */
    function _takeFee(address sender, uint256 amount) internal returns (uint256) {
        uint256 feeAmount = 0;

        // Anti-Whale Check
        if(amount >= whaleThreshold) {
            require(block.timestamp - lastWhaleTradeTime[sender] >= whaleCooldown, "Anti-Whale: Cooldown in effect");
            feeAmount = (amount * higherTaxRate) / 100;
            lastWhaleTradeTime[sender] = block.timestamp;
        }
        else {
            // No additional fees since swap and liquify is removed
            feeAmount = 0;
        }

        if(feeAmount > 0) {
            _balances[address(this)] += feeAmount;
            emit Transfer(sender, address(this), feeAmount);
        }

        return amount - feeAmount;
    }

    /**
     * @dev Internal function to approve tokens.
     */
    function _approve(address ownerAddr, address spender, uint256 amount) private {
        require(ownerAddr != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[ownerAddr][spender] = amount;
        emit Approval(ownerAddr, spender, amount);
    }

    // =========================
    // Referral System
    // =========================

    /**
     * @dev Allows a user to set their referrer. Can only be set once.
     */
    function setReferral(address _referrer) external {
        require(referrer[msg.sender] == address(0), "Referrer already set");
        require(_referrer != msg.sender, "Cannot refer yourself");
        require(_referrer != address(0), "Referrer cannot be zero address");

        referrer[msg.sender] = _referrer;
        emit ReferralSet(msg.sender, _referrer);
    }

    /**
     * @dev Internal function to reward referrers.
     */
    function rewardReferral(address recipient, uint256 amount) internal {
        address _referrer = referrer[recipient];
        if(_referrer != address(0)) {
            uint256 reward = amount / 100; // 1% referral reward
            _balances[_referrer] += reward;
            emit Transfer(address(this), _referrer, reward);
        }
    }

    // =========================
    // Airdrop Functionality
    // =========================

    /**
     * @dev Allows the owner to airdrop tokens to multiple addresses.
     */
    function airdropTokens(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner nonReentrant whenNotPaused {
        require(recipients.length == amounts.length, "Airdrop: recipients and amounts length mismatch");
        for(uint256 i = 0; i < recipients.length; i++) {
            _transfer(_msgSender(), recipients[i], amounts[i]);
        }
    }

    // =========================
    // Burn Functionality
    // =========================

    /**
     * @dev Allows a user to burn their own tokens.
     */
    function burn(uint256 amount) external whenNotPaused nonReentrant {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Internal function to burn tokens.
     */
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "Burn: burn from the zero address");
        require(_balances[account] >= amount, "Burn: burn amount exceeds balance");

        _balances[account] -= amount;
        _totalSupply -= amount;
        emit Transfer(account, deadAddress, amount);
    }

    // =========================
    // Vesting Mechanism
    // =========================

    /**
     * @dev Sets a vesting schedule for an account.
     */
    function setVestingSchedule(address account, uint256 totalAmount, uint256 releaseTime) external onlyOwner {
        require(account != address(0), "Vesting: invalid account");
        require(totalAmount > 0, "Vesting: total amount must be greater than zero");
        require(releaseTime > block.timestamp, "Vesting: release time must be in the future");

        vestingSchedules[account] = VestingSchedule({
            totalAmount: totalAmount,
            amountReleased: 0,
            releaseTime: releaseTime,
            isActive: true
        });

        emit VestingScheduleSet(account, totalAmount, releaseTime);
    }

    /**
     * @dev Allows beneficiaries to release their vested tokens after the release time.
     */
    function releaseVestedTokens() external nonReentrant whenNotPaused {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.isActive, "Vesting: no active schedule");
        require(block.timestamp >= schedule.releaseTime, "Vesting: tokens are still locked");
        require(schedule.amountReleased < schedule.totalAmount, "Vesting: all tokens have been released");

        uint256 amountToRelease = schedule.totalAmount - schedule.amountReleased;
        require(amountToRelease > 0, "Vesting: no tokens available for release");

        schedule.amountReleased += amountToRelease;
        if(schedule.amountReleased >= schedule.totalAmount) {
            schedule.isActive = false;
        }

        _transfer(address(this), msg.sender, amountToRelease);
        emit VestingTokensReleased(msg.sender, amountToRelease);
        emit TokensReleased(msg.sender, amountToRelease);
    }

    // =========================
    // Owner Functions
    // =========================

    /**
     * @dev Allows the owner to update the maximum gas price.
     */
    function updateMaxGasPrice(uint256 newGasPrice) external onlyOwner {
        require(newGasPrice > 0, "Owner: gas price must be greater than zero");
        maxGasPrice = newGasPrice;
    }

    /**
     * @dev Allows the owner to update the transaction cooldown time.
     */
    function updateTxCooldownTime(uint256 newCooldown) external onlyOwner {
        require(newCooldown >= 30, "Owner: cooldown too short");
        txCooldownTime = newCooldown;
    }

    /**
     * @dev Allows the owner to set the maximum transaction amount.
     */
    function setMaxTxAmount(uint256 newMaxTxAmount) external onlyOwner {
        require(newMaxTxAmount >= _totalSupply / 1000, "Owner: maxTxAmount too low"); // At least 0.1%
        maxTxAmount = newMaxTxAmount;
    }

    /**
     * @dev Allows the owner to set the maximum wallet size.
     */
    function setWalletMax(uint256 newWalletMax) external onlyOwner {
        require(newWalletMax >= _totalSupply / 500, "Owner: walletMax too low"); // At least 0.2%
        walletMax = newWalletMax;
    }

    /**
     * @dev Allows the owner to set the minimum tokens before swap.
     */
    function setMinimumTokensBeforeSwap(uint256 newLimit) external onlyOwner {
        minimumTokensBeforeSwap = newLimit;
    }

    /**
     * @dev Allows the owner to enable or disable swap and liquify.
     * Note: Swap and liquify functionalities have been removed to resolve compilation errors.
     * This function is retained for future flexibility if swap and liquify features are reintroduced.
     */
    function setSwapAndLiquifyEnabled(bool _enabled) external onlyOwner {
        swapAndLiquifyEnabled = _enabled;
    }

    /**
     * @dev Allows the owner to enable or disable wallet limit checks.
     */
    function setCheckWalletLimit(bool _enabled) external onlyOwner {
        checkWalletLimit = _enabled;
    }

    /**
     * @dev Allows the owner to set buy taxes.
     */
    uint256 public constant MAX_BUY_TAX = 10; // 10%
    function setBuyTaxes(uint256 newLiquidityFee, uint256 newMarketingFee, uint256 newTeamFee, uint256 newDonationFee) external onlyOwner {
        require(newLiquidityFee + newMarketingFee + newTeamFee + newDonationFee <= MAX_BUY_TAX, "Owner: buy taxes exceed limit");
        buyLiquidityFee = newLiquidityFee;
        buyMarketingFee = newMarketingFee;
        buyTeamFee = newTeamFee;
        buyDonationFee = newDonationFee;
        totalTaxIfBuying = buyLiquidityFee + buyMarketingFee + buyTeamFee + buyDonationFee;
    }

    /**
     * @dev Allows the owner to set sell taxes.
     */
    uint256 public constant MAX_SELL_TAX = 10; // 10%
    function setSellTaxes(uint256 newLiquidityFee, uint256 newMarketingFee, uint256 newTeamFee, uint256 newDonationFee) external onlyOwner {
        require(newLiquidityFee + newMarketingFee + newTeamFee + newDonationFee <= MAX_SELL_TAX, "Owner: sell taxes exceed limit");
        sellLiquidityFee = newLiquidityFee;
        sellMarketingFee = newMarketingFee;
        sellTeamFee = newTeamFee;
        sellDonationFee = newDonationFee;
        totalTaxIfSelling = sellLiquidityFee + sellMarketingFee + sellTeamFee + sellDonationFee;
    }

    // =========================
    // Fallback Functions
    // =========================

    /**
     * @dev Fallback function to receive ETH.
     */
    receive() external payable {}
    
    fallback() external payable {}
}
