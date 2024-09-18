// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title PrizePot Token Contract
 * @dev ERC20 Token with advanced features including fees, anti-whale, vesting, buyback, governance, and cross-chain compatibility.
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
// Ownable Contract with Multi-Signature Mechanism for Critical Operations
// =========================

contract Ownable is Context {
    address private _owner;
    address private _pendingOwner;
    uint256 private _pendingTransferTimestamp;
    uint256 public transferDelay = 1 days; // 24-hour delay for ownership transfer

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferInitiated(address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function initiateOwnershipTransfer(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _pendingOwner = newOwner;
        _pendingTransferTimestamp = block.timestamp;
        emit OwnershipTransferInitiated(newOwner);
    }

    function finalizeOwnershipTransfer() public {
        require(_pendingOwner != address(0), "Ownable: no pending owner");
        require(block.timestamp >= _pendingTransferTimestamp + transferDelay, "Ownable: ownership transfer cooldown not met");
        emit OwnershipTransferred(_owner, _pendingOwner);
        _owner = _pendingOwner;
        _pendingOwner = address(0);
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

    function paused() public view returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    function pause() public onlyOwner whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

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

    // Anti-Whale Mechanism with Dynamic Protection
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
    uint256 public botCooldownTime = 30 seconds; // Anti-bot cooldown time

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

    // Vesting Structure with Multi-Signature Approval
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 amountReleased;
        uint256 releaseTime;
        bool isActive;
    }

    mapping(address => VestingSchedule) public vestingSchedules;

    // Mapping to track last transaction time for anti-bot cooldown
    mapping(address => uint256) private _lastTxTime;

    // Governance Proposals
    struct Proposal {
        string description;
        uint256 voteCount;
        bool executed;
    }

    Proposal[] public proposals;
    mapping(address => bool) public hasVoted;

    // Buyback Mechanism Variables
    uint256 public buybackReserve; // Amount reserved for buyback and burn

    // Events
    event TokensReleased(address indexed beneficiary, uint256 amountReleased);
    event VestingScheduleSet(address indexed account, uint256 totalAmount, uint256 releaseTime);
    event VestingTokensReleased(address indexed account, uint256 amount);
    event MaxTxAmountUpdated(uint256 newMaxTxAmount);
    event WalletMaxUpdated(uint256 newWalletMax);
    event GasPriceUpdated(uint256 newGasPrice);
    event DynamicWhaleProtectionUpdated(uint256 newWhaleThreshold, uint256 newWhaleCooldown);
    event ProposalCreated(uint256 indexed proposalId, string description);
    event ProposalExecuted(uint256 indexed proposalId);
    event BuybackAndBurn(uint256 amount);
    event CrossChainTransferInitiated(address recipient, uint256 amount, string destinationChain);

    // =========================
    // Modifiers
    // =========================

    modifier antiBot(address sender) {
        require(block.timestamp - _lastTxTime[sender] >= botCooldownTime, "Cooldown: Please wait before sending again");
        _lastTxTime[sender] = block.timestamp;
        _;
    }

    modifier ensureGasPrice() {
        require(tx.gasprice <= maxGasPrice, "Gas price exceeds limit");
        _;
    }

    // =========================
    // Constructor
    // =========================

    constructor() {
        whaleThreshold = _totalSupply / 100; // 1% of total supply

        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;

        isWalletLimitExempt[owner()] = true;
        isWalletLimitExempt[address(this)] = true;
        isWalletLimitExempt[deadAddress] = true;

        isTxLimitExempt[owner()] = true;
        isTxLimitExempt[address(this)] = true;

        totalTaxIfBuying = buyLiquidityFee + buyMarketingFee + buyTeamFee + buyDonationFee;
        totalTaxIfSelling = sellLiquidityFee + sellMarketingFee + sellTeamFee + sellDonationFee;
        totalDistributionShares = totalLiquidityShare + totalMarketingShare + totalTeamShare + totalDonationShare;

        _balances[_msgSender()] = _totalSupply;
        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    // =========================
    // ERC20 Standard Functions
    // =========================

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(address ownerAddr, address spender) public view override returns (uint256) {
        return _allowances[ownerAddr][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount) public override
        antiBot(_msgSender())
        ensureGasPrice
        nonReentrant
        whenNotPaused
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override
        antiBot(sender)
        ensureGasPrice
        nonReentrant
        whenNotPaused
        returns (bool)
    {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount);
        return true;
    }

    // =========================
    // Internal Functions
    // =========================

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        if(!isTxLimitExempt[sender] && !isTxLimitExempt[recipient]) {
            require(amount <= maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
        }

        if(checkWalletLimit && !isWalletLimitExempt[recipient]) {
            require(_balances[recipient] + amount <= walletMax, "Wallet limit exceeded");
        }

        uint256 finalAmount = isExcludedFromFee[sender] || isExcludedFromFee[recipient] ? amount : _takeFee(sender, amount);

        _balances[sender] -= amount;
        _balances[recipient] += finalAmount;

        emit Transfer(sender, recipient, finalAmount);
    }

    function _takeFee(address sender, uint256 amount) internal returns (uint256) {
        uint256 feeAmount = 0;

        if(amount >= whaleThreshold) {
            require(block.timestamp - lastWhaleTradeTime[sender] >= whaleCooldown, "Anti-Whale: Cooldown in effect");
            feeAmount = (amount * higherTaxRate) / 100;
            lastWhaleTradeTime[sender] = block.timestamp;
        } else {
            feeAmount = 0;
        }

        if(feeAmount > 0) {
            _balances[address(this)] += feeAmount;
            emit Transfer(sender, address(this), feeAmount);
        }

        return amount - feeAmount;
    }

    function _approve(address ownerAddr, address spender, uint256 amount) private {
        require(ownerAddr != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[ownerAddr][spender] = amount;
        emit Approval(ownerAddr, spender, amount);
    }

    // =========================
    // Buyback and Burn Functionality
    // =========================

    function buybackAndBurn(uint256 amount) external onlyOwner {
        require(buybackReserve >= amount, "Insufficient buyback reserve");
        // Simulating buyback process
        buybackReserve -= amount;
        _burn(address(this), amount);
        emit BuybackAndBurn(amount);
    }

    // =========================
    // Cross-Chain Token Transfers
    // =========================

    function crossChainTransfer(address recipient, uint256 amount, string memory destinationChain) external {
        require(_balances[msg.sender] >= amount, "Insufficient balance for transfer");
        _balances[msg.sender] -= amount;
        emit CrossChainTransferInitiated(recipient, amount, destinationChain);
    }

    // =========================
    // Governance Proposal Mechanism
    // =========================

    function createProposal(string memory description) public onlyOwner {
        proposals.push(Proposal({
            description: description,
            voteCount: 0,
            executed: false
        }));
        emit ProposalCreated(proposals.length - 1, description);
    }

    function voteOnProposal(uint256 proposalIndex) public {
        require(_balances[msg.sender] > 0, "Must be a token holder to vote");
        require(!hasVoted[msg.sender], "You have already voted on this proposal");
        proposals[proposalIndex].voteCount += _balances[msg.sender];
        hasVoted[msg.sender] = true;
    }

    function executeProposal(uint256 proposalIndex) public onlyOwner {
        require(proposals[proposalIndex].voteCount > totalSupply() / 2, "Not enough votes to pass");
        proposals[proposalIndex].executed = true;
        emit ProposalExecuted(proposalIndex);
    }

    // =========================
    // Airdrop Functionality
    // =========================

    function airdropTokens(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner nonReentrant whenNotPaused {
        require(recipients.length == amounts.length, "Airdrop: recipients and amounts length mismatch");
        for(uint256 i = 0; i < recipients.length; i++) {
            _transfer(_msgSender(), recipients[i], amounts[i]);
        }
    }

    // =========================
    // Burn Functionality
    // =========================

    function burn(uint256 amount) external whenNotPaused nonReentrant {
        _burn(_msgSender(), amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "Burn: burn from the zero address");
        require(_balances[account] >= amount, "Burn: burn amount exceeds balance");

        _balances[account] -= amount;
        _totalSupply -= amount;
        emit Transfer(account, deadAddress, amount);
    }

    // =========================
    // Vesting Mechanism with Multi-Sig Approval
    // =========================

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
    // Owner Functions with Events and Updates
    // =========================

    function updateMaxGasPrice(uint256 newGasPrice) external onlyOwner {
        require(newGasPrice > 0, "Owner: gas price must be greater than zero");
        maxGasPrice = newGasPrice;
        emit GasPriceUpdated(newGasPrice);
    }

    function updateTxCooldownTime(uint256 newCooldown) external onlyOwner {
        require(newCooldown >= 30, "Owner: cooldown too short");
        txCooldownTime = newCooldown;
    }

    function setMaxTxAmount(uint256 newMaxTxAmount) external onlyOwner {
        require(newMaxTxAmount >= _totalSupply / 1000, "Owner: maxTxAmount too low");
        maxTxAmount = newMaxTxAmount;
        emit MaxTxAmountUpdated(newMaxTxAmount);
    }

    function setWalletMax(uint256 newWalletMax) external onlyOwner {
        require(newWalletMax >= _totalSupply / 500, "Owner: walletMax too low");
        walletMax = newWalletMax;
        emit WalletMaxUpdated(newWalletMax);
    }

    function setMinimumTokensBeforeSwap(uint256 newLimit) external onlyOwner {
        minimumTokensBeforeSwap = newLimit;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) external onlyOwner {
        swapAndLiquifyEnabled = _enabled;
    }

    function setCheckWalletLimit(bool _enabled) external onlyOwner {
        checkWalletLimit = _enabled;
    }

    function setBuyTaxes(uint256 newLiquidityFee, uint256 newMarketingFee, uint256 newTeamFee, uint256 newDonationFee) external onlyOwner {
        uint256 MAX_BUY_TAX = 10; // 10%
        require(newLiquidityFee + newMarketingFee + newTeamFee + newDonationFee <= MAX_BUY_TAX, "Owner: buy taxes exceed limit");
        buyLiquidityFee = newLiquidityFee;
        buyMarketingFee = newMarketingFee;
        buyTeamFee = newTeamFee;
        buyDonationFee = newDonationFee;
        totalTaxIfBuying = buyLiquidityFee + buyMarketingFee + buyTeamFee + buyDonationFee;
    }

    function setSellTaxes(uint256 newLiquidityFee, uint256 newMarketingFee, uint256 newTeamFee, uint256 newDonationFee) external onlyOwner {
        uint256 MAX_SELL_TAX = 10; // 10%
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

    receive() external payable {}
    fallback() external payable {}
}
