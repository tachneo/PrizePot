// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

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
    function burn(uint256 amount) external;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed ownerAddr, address indexed spender, uint256 value);
}

// =========================
// Ownable2Step Contract for Safer Ownership Transfers
// =========================

contract Ownable2Step is Context {
    address private _owner;
    address private _pendingOwner;

    error CallerIsNotOwner();
    error NewOwnerIsZeroAddress();
    error OnlyPendingOwnerCanAccept();

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferInitiated(address indexed newOwner);

    constructor() {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        if (_owner != _msgSender()) revert CallerIsNotOwner();
        _;
    }

    function initiateOwnershipTransfer(address newOwner) public onlyOwner {
        if (newOwner == address(0)) revert NewOwnerIsZeroAddress();
        _pendingOwner = newOwner;
        emit OwnershipTransferInitiated(newOwner);
    }

    function finalizeOwnershipTransfer() public {
        if (_pendingOwner != _msgSender()) revert OnlyPendingOwnerCanAccept();
        emit OwnershipTransferred(_owner, _pendingOwner);
        _owner = _pendingOwner;
        _pendingOwner = address(0);
    }
}

// =========================
// ReentrancyGuard Contract with Custom Error
// =========================

contract ReentrancyGuard {
    uint256 private _status;

    error ReentrantCall();

    constructor() {
        _status = 1;
    }

    modifier nonReentrant() {
        if (_status == 2) revert ReentrantCall();
        _status = 2;
        _;
        _status = 1;
    }
}

// =========================
// Pausable Contract with Custom Errors
// =========================

contract Pausable is Context, Ownable2Step {
    event Paused(address account);
    event Unpaused(address account);

    bool private _paused;

    error ContractIsPaused();
    error ContractIsNotPaused();

    constructor() {
        _paused = false;
    }

    function paused() public view returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        if (_paused) revert ContractIsPaused();
        _;
    }

    modifier whenPaused() {
        if (!_paused) revert ContractIsNotPaused();
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
// SafeMath Library for Safe Arithmetic Operations
// =========================

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) revert("Addition overflow");
            return c;
        }
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            if (b > a) revert("Subtraction overflow");
            return a - b;
        }
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            if (a == 0) return 0;
            uint256 c = a * b;
            if (c / a != b) revert("Multiplication overflow");
            return c;
        }
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            if (b == 0) revert("Division by zero");
            return a / b;
        }
    }
}

// =========================
// Address Library for Safe Address Operations
// =========================

library Address {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) revert("Insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) revert("Unable to send value");
    }
}

// =========================
// Interfaces for Uniswap
// =========================

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    // other functions omitted for brevity
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    // Swap functions
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    // Liquidity functions
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (
        uint amountToken,
        uint amountETH,
        uint liquidity
    );

    // other functions omitted for brevity
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    // other functions omitted for brevity
}

// =========================
// PrizePot Contract with Implemented Swap and Liquify
// =========================

contract PrizePot is Context, IERC20, Ownable2Step, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using Address for address payable;

    // Token details
    string private constant _name = "Prize Pot";
    string private constant _symbol = "PPOT";
    uint8 private constant _decimals = 9;
    uint256 private _totalSupply = 1_000_000_000_000 * (10 ** _decimals);

    // Mappings
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // Fee exemptions
    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isWalletLimitExempt;
    mapping(address => bool) public isTxLimitExempt;

    // Anti-whale mechanism
    uint256 public whaleThreshold;
    uint256 public higherTaxRate = 15; // 15%
    uint256 public whaleCooldown = 1 hours;
    mapping(address => uint256) private _lastWhaleTradeTime;

    // Transaction limits
    uint256 public maxTxAmount = 10_000_000_000 * (10 ** _decimals);
    uint256 public walletMax = 20_000_000_000 * (10 ** _decimals);
    uint256 private constant _minimumTokensBeforeSwap = 500_000_000 * (10 ** _decimals);

    // Fee percentages
    uint256 public buyLiquidityFee = 2;
    uint256 public buyMarketingFee = 2;
    uint256 public buyTeamFee = 2;
    uint256 public buyDonationFee = 1;

    uint256 public sellLiquidityFee = 3;
    uint256 public sellMarketingFee = 2;
    uint256 public sellTeamFee = 3;
    uint256 public sellDonationFee = 1;

    // Total shares and taxes
    uint256 public totalTaxIfBuying;
    uint256 public totalTaxIfSelling;
    uint256 public totalDistributionShares;

    // Address constants
    address payable public marketingWallet;
    address payable public teamWallet;
    address payable public liquidityWallet;
    address payable public donationWallet;
    address public immutable deadAddress = address(0xdead);

    // Booleans
    bool private _inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    bool public checkWalletLimit = true;

    // Vesting
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 amountReleased;
        uint256 releaseTime;
        bool isActive;
    }

    mapping(address => VestingSchedule) public vestingSchedules;

    // Anti-bot
    mapping(address => uint256) private _lastTxTime;
    uint256 public botCooldownTime = 30 seconds;

    // Governance
    struct Proposal {
        string description;
        uint256 voteCount;
        bool executed;
    }

    Proposal[] public proposals;
    mapping(address => mapping(uint256 => bool)) public hasVoted;

    // Buyback reserve
    uint256 public buybackReserve;

    // Uniswap Variables
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapPair;

    // Events
    event TokensReleased(address indexed beneficiary, uint256 amountReleased);
    event VestingScheduleSet(address indexed account, uint256 totalAmount, uint256 releaseTime);
    event VestingTokensReleased(address indexed account, uint256 amount);
    event MaxTxAmountUpdated(uint256 newMaxTxAmount);
    event WalletMaxUpdated(uint256 newWalletMax);
    event ProposalCreated(uint256 indexed proposalId, string description);
    event ProposalExecuted(uint256 indexed proposalId);
    event BuybackAndBurn(uint256 amount);
    event CrossChainTransferInitiated(address recipient, uint256 amount, string destinationChain);
    event EtherWithdrawn(address indexed owner, uint256 amount);
    event AirdropExecuted(uint256 totalAddresses, uint256 totalAmount);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiquidity);
    event FeesDistributed(uint256 marketingFee, uint256 teamFee, uint256 donationFee);

    // Custom Errors
    error TransferFromZeroAddress();
    error TransferToZeroAddress();
    error MaxTxLimitExceeded();
    error WalletLimitExceeded();
    error AntiWhaleCooldown();
    error ApproveFromZeroAddress();
    error ApproveToZeroAddress();
    error InsufficientBuybackReserve();
    error InsufficientBalance();
    error MustBeTokenHolder();
    error AlreadyVoted();
    error NotEnoughVotes();
    error RecipientsAmountsMismatch();
    error BurnFromZeroAddress();
    error BurnAmountExceedsBalance();
    error InvalidAccount();
    error AmountMustBeGreaterThanZero();
    error ReleaseTimeMustBeInFuture();
    error NoActiveSchedule();
    error TokensStillLocked();
    error AllTokensReleased();
    error NoTokensToRelease();
    error MaxTxAmountTooLow();
    error WalletMaxTooLow();
    error BuyTaxesExceedLimit();
    error SellTaxesExceedLimit();
    error NoEtherAvailable();
    error EtherWithdrawalFailed();
    error ArrayLengthExceedsLimit();
    error SwapAndLiquifyFailed();

    // Modifiers
    modifier antiBot(address sender) {
        if (block.timestamp - _lastTxTime[sender] < botCooldownTime) revert AntiWhaleCooldown();
        _lastTxTime[sender] = block.timestamp;
        _;
    }

    modifier lockTheSwap() {
        _inSwapAndLiquify = true;
        _;
        _inSwapAndLiquify = false;
    }

    // Constructor
    constructor() payable {
        whaleThreshold = _totalSupply / 100;

        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;

        isWalletLimitExempt[owner()] = true;
        isWalletLimitExempt[address(this)] = true;
        isWalletLimitExempt[deadAddress] = true;

        isTxLimitExempt[owner()] = true;
        isTxLimitExempt[address(this)] = true;

        totalTaxIfBuying = buyLiquidityFee.add(buyMarketingFee).add(buyTeamFee).add(buyDonationFee);
        totalTaxIfSelling = sellLiquidityFee.add(sellMarketingFee).add(sellTeamFee).add(sellDonationFee);
        totalDistributionShares = buyLiquidityFee.add(buyMarketingFee).add(buyTeamFee).add(buyDonationFee);

        // Initialize wallets
        marketingWallet = payable(0x666eda6bD98e24EaF8bcA9D1DD46617ECd61E5b2);
        teamWallet = payable(0x0de504d353375A999d2d983eC37Ed6FFd186CbA1);
        liquidityWallet = payable(0x8aF9D64eF4Eea9806FD191a33493b238B90A4d86);
        donationWallet = payable(0xf1214dBF1D1285D293604601154327A78580E6A4);

        _balances[_msgSender()] = _totalSupply;
        emit Transfer(address(0), _msgSender(), _totalSupply);

        // Initialize Uniswap Router and create pair
        // For Ethereum mainnet, the router address is 0x7a250d5630B4cf539739dF2C5dAcb4c659F2488D
        // For other networks, replace with the appropriate router address
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cf539739dF2C5dAcb4c659F2488D // Uniswap V2 Router address
        );

        // Create a uniswap pair for this token
        uniswapPair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;

        // Exclude pair from fees and limits
        isWalletLimitExempt[uniswapPair] = true;
        isTxLimitExempt[uniswapPair] = true;
    }

    // ERC20 Standard Functions
    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
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

    function approve(address spender, uint256 amount) public override whenNotPaused returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        nonReentrant
        whenNotPaused
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override nonReentrant whenNotPaused returns (bool) {
        _transfer(sender, recipient, amount);
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        if (currentAllowance < amount) revert InsufficientBalance();
        _approve(sender, _msgSender(), currentAllowance.sub(amount));
        return true;
    }

    // Ether Withdrawal
    function withdrawEther() external onlyOwner nonReentrant {
        uint256 contractBalance = address(this).balance;
        if (contractBalance == 0) revert NoEtherAvailable();
        payable(owner()).sendValue(contractBalance);
        emit EtherWithdrawn(owner(), contractBalance);
    }

    // Internal Functions
    function _transfer(address sender, address recipient, uint256 amount) internal antiBot(sender) {
        if (sender == address(0)) revert TransferFromZeroAddress();
        if (recipient == address(0)) revert TransferToZeroAddress();

        if (!isTxLimitExempt[sender] && !isTxLimitExempt[recipient]) {
            if (amount > maxTxAmount) revert MaxTxLimitExceeded();
        }

        if (checkWalletLimit && !isWalletLimitExempt[recipient]) {
            if (_balances[recipient].add(amount) > walletMax) revert WalletLimitExceeded();
        }

        uint256 finalAmount = amount;

        if (!isExcludedFromFee[sender] && !isExcludedFromFee[recipient]) {
            finalAmount = _takeFee(sender, recipient, amount);
        }

        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(finalAmount);

        emit Transfer(sender, recipient, finalAmount);

        if (swapAndLiquifyEnabled && !_inSwapAndLiquify && sender != uniswapPair) {
            uint256 contractTokenBalance = _balances[address(this)];
            if (contractTokenBalance >= _minimumTokensBeforeSwap) {
                swapAndLiquify(contractTokenBalance);
            }
        }
    }

    function _takeFee(address sender, address recipient, uint256 amount) internal returns (uint256) {
        uint256 feeAmount = 0;
        uint256 totalFee = 0;

        if (amount >= whaleThreshold) {
            if (block.timestamp - _lastWhaleTradeTime[sender] < whaleCooldown) revert AntiWhaleCooldown();
            feeAmount = amount.mul(higherTaxRate).div(100);
            _lastWhaleTradeTime[sender] = block.timestamp;
        } else {
            if (sender == uniswapPair) {
                // Buy transaction
                totalFee = totalTaxIfBuying;
            } else if (recipient == uniswapPair) {
                // Sell transaction
                totalFee = totalTaxIfSelling;
            } else {
                // Transfer transaction
                totalFee = totalTaxIfBuying;
            }
            feeAmount = amount.mul(totalFee).div(100);
        }

        if (feeAmount > 0) {
            _balances[address(this)] = _balances[address(this)].add(feeAmount);
            emit Transfer(sender, address(this), feeAmount);
        }

        return amount.sub(feeAmount);
    }

    function _approve(
        address ownerAddr,
        address spender,
        uint256 amount
    ) private {
        if (ownerAddr == address(0)) revert ApproveFromZeroAddress();
        if (spender == address(0)) revert ApproveToZeroAddress();

        _allowances[ownerAddr][spender] = amount;
        emit Approval(ownerAddr, spender, amount);
    }

    // Swap and Liquify Functionality
    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        uint256 totalFee = totalDistributionShares;

        uint256 liquidityTokens = contractTokenBalance.mul(buyLiquidityFee).div(totalFee).div(2);
        uint256 tokensToSwap = contractTokenBalance.sub(liquidityTokens);

        uint256 initialBalance = address(this).balance;

        swapTokensForEth(tokensToSwap);

        uint256 newBalance = address(this).balance.sub(initialBalance);

        uint256 totalETHFee = totalFee.sub(buyLiquidityFee.div(2));

        uint256 liquidityETH = newBalance.mul(buyLiquidityFee).div(totalETHFee).div(2);
        uint256 marketingETH = newBalance.mul(buyMarketingFee).div(totalETHFee);
        uint256 teamETH = newBalance.mul(buyTeamFee).div(totalETHFee);
        uint256 donationETH = newBalance.mul(buyDonationFee).div(totalETHFee);

        if (liquidityETH > 0 && liquidityTokens > 0) {
            addLiquidity(liquidityTokens, liquidityETH);
            emit SwapAndLiquify(tokensToSwap, newBalance, liquidityTokens);
        }

        marketingWallet.sendValue(marketingETH);
        teamWallet.sendValue(teamETH);
        donationWallet.sendValue(donationETH);

        emit FeesDistributed(marketingETH, teamETH, donationETH);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // Generate the Uniswap pair path of token -> WETH (ETH)
        address;
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // Make the swap and send ETH to this contract
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // Approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // Add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            liquidityWallet, // Liquidity tokens are sent to the liquidity wallet
            block.timestamp
        );
    }

    // Buyback and Burn Functionality
    function buybackAndBurn(uint256 amount) external onlyOwner {
        if (buybackReserve < amount) revert InsufficientBuybackReserve();
        buybackReserve = buybackReserve.sub(amount);
        _burn(address(this), amount);
        emit BuybackAndBurn(amount);
    }

    // Cross-Chain Token Transfers
    function crossChainTransfer(
        address recipient,
        uint256 amount,
        string memory destinationChain
    ) external nonReentrant whenNotPaused {
        if (_balances[_msgSender()] < amount) revert InsufficientBalance();
        _burn(_msgSender(), amount);
        emit CrossChainTransferInitiated(recipient, amount, destinationChain);
    }

    // Governance Proposal Mechanism
    function createProposal(string memory description) public onlyOwner {
        proposals.push(
            Proposal({
                description: description,
                voteCount: 0,
                executed: false
            })
        );
        emit ProposalCreated(proposals.length - 1, description);
    }

    function voteOnProposal(uint256 proposalIndex) public {
        if (_balances[_msgSender()] == 0) revert MustBeTokenHolder();
        if (hasVoted[_msgSender()][proposalIndex]) revert AlreadyVoted();
        proposals[proposalIndex].voteCount = proposals[proposalIndex].voteCount.add(_balances[_msgSender()]);
        hasVoted[_msgSender()][proposalIndex] = true;
    }

    function executeProposal(uint256 proposalIndex) public onlyOwner {
        if (proposals[proposalIndex].voteCount <= _totalSupply.div(2)) revert NotEnoughVotes();
        proposals[proposalIndex].executed = true;
        emit ProposalExecuted(proposalIndex);
    }

    // Airdrop Functionality
    function airdropTokens(address[] calldata recipients, uint256[] calldata amounts)
        external
        onlyOwner
        nonReentrant
        whenNotPaused
    {
        uint256 length = recipients.length;
        if (length != amounts.length) revert RecipientsAmountsMismatch();
        uint256 MAX_ARRAY_LENGTH = 100; // Limit to prevent gas issues
        if (length > MAX_ARRAY_LENGTH) revert ArrayLengthExceedsLimit();
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < length; ++i) {
            _transfer(_msgSender(), recipients[i], amounts[i]);
            totalAmount = totalAmount.add(amounts[i]);
        }
        emit AirdropExecuted(length, totalAmount);
    }

    // Burn Functionality
    function burn(uint256 amount) external override whenNotPaused nonReentrant {
        _burn(_msgSender(), amount);
    }

    function _burn(address account, uint256 amount) internal {
        if (account == address(0)) revert BurnFromZeroAddress();
        if (_balances[account] < amount) revert BurnAmountExceedsBalance();

        _balances[account] = _balances[account].sub(amount);
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, deadAddress, amount);
    }

    // Vesting Mechanism
    function setVestingSchedule(
        address account,
        uint256 totalAmount,
        uint256 releaseTime
    ) external onlyOwner {
        if (account == address(0)) revert InvalidAccount();
        if (totalAmount == 0) revert AmountMustBeGreaterThanZero();
        if (releaseTime <= block.timestamp) revert ReleaseTimeMustBeInFuture();

        VestingSchedule storage schedule = vestingSchedules[account];
        schedule.totalAmount = totalAmount;
        schedule.amountReleased = 0;
        schedule.releaseTime = releaseTime;
        schedule.isActive = true;

        emit VestingScheduleSet(account, totalAmount, releaseTime);
    }

    function releaseVestedTokens() external nonReentrant whenNotPaused {
        VestingSchedule storage schedule = vestingSchedules[_msgSender()];
        if (!schedule.isActive) revert NoActiveSchedule();
        if (block.timestamp < schedule.releaseTime) revert TokensStillLocked();
        if (schedule.amountReleased >= schedule.totalAmount) revert AllTokensReleased();

        uint256 amountToRelease = schedule.totalAmount.sub(schedule.amountReleased);
        if (amountToRelease == 0) revert NoTokensToRelease();

        schedule.amountReleased = schedule.totalAmount;
        schedule.isActive = false;

        _transfer(address(this), _msgSender(), amountToRelease);
        emit VestingTokensReleased(_msgSender(), amountToRelease);
        emit TokensReleased(_msgSender(), amountToRelease);
    }

    // Owner Functions
    function updateMaxTxAmount(uint256 newMaxTxAmount) external onlyOwner {
        if (newMaxTxAmount < _totalSupply.div(1000)) revert MaxTxAmountTooLow();
        maxTxAmount = newMaxTxAmount;
        emit MaxTxAmountUpdated(newMaxTxAmount);
    }

    function setWalletMax(uint256 newWalletMax) external onlyOwner {
        if (newWalletMax < _totalSupply.div(500)) revert WalletMaxTooLow();
        walletMax = newWalletMax;
        emit WalletMaxUpdated(newWalletMax);
    }

    function setBuyTaxes(
        uint256 newLiquidityFee,
        uint256 newMarketingFee,
        uint256 newTeamFee,
        uint256 newDonationFee
    ) external onlyOwner {
        uint256 MAX_BUY_TAX = 10;
        if (newLiquidityFee.add(newMarketingFee).add(newTeamFee).add(newDonationFee) > MAX_BUY_TAX)
            revert BuyTaxesExceedLimit();
        buyLiquidityFee = newLiquidityFee;
        buyMarketingFee = newMarketingFee;
        buyTeamFee = newTeamFee;
        buyDonationFee = newDonationFee;
        totalTaxIfBuying = buyLiquidityFee.add(buyMarketingFee).add(buyTeamFee).add(buyDonationFee);
    }

    function setSellTaxes(
        uint256 newLiquidityFee,
        uint256 newMarketingFee,
        uint256 newTeamFee,
        uint256 newDonationFee
    ) external onlyOwner {
        uint256 MAX_SELL_TAX = 10;
        if (newLiquidityFee.add(newMarketingFee).add(newTeamFee).add(newDonationFee) > MAX_SELL_TAX)
            revert SellTaxesExceedLimit();
        sellLiquidityFee = newLiquidityFee;
        sellMarketingFee = newMarketingFee;
        sellTeamFee = newTeamFee;
        sellDonationFee = newDonationFee;
        totalTaxIfSelling = sellLiquidityFee.add(sellMarketingFee).add(sellTeamFee).add(sellDonationFee);
    }

    function setSwapAndLiquifyEnabled(bool _enabled) external onlyOwner {
        swapAndLiquifyEnabled = _enabled;
    }

    function setCheckWalletLimit(bool _enabled) external onlyOwner {
        checkWalletLimit = _enabled;
    }

    // Fallback Functions
    receive() external payable {
        // Allow contract to receive Ether
    }

    fallback() external payable {
        // Allow contract to receive Ether
    }
}

