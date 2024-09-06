// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

contract MemeCoin is Context, IERC20, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using Address for address;

    string private _name = "Prize Pot";
    string private _symbol = "PPOT";
    uint8 private _decimals = 9;
    
    uint256 private _totalSupply = 1000000000000 * 10**9; // 1 trillion total supply
    uint256 public _maxTxAmount = 10000000000 * 10**9; // Max transaction size (1% of total supply)
    uint256 public _walletMax = 20000000000 * 10**9; // Max wallet size (2% of total supply)
    uint256 private minimumTokensBeforeSwap = 500000000 * 10**9; // 0.05% of total supply
    
    address payable public marketingWallet = payable(0x666eda6bD98e24EaF8bcA9D1DD46617ECd61E5b2);
    address payable public teamWallet = payable(0x0de504d353375A999d2d983eC37Ed6FFd186CbA1);
    address payable public liquidityWallet = payable(0x8aF9D64eF4Eea9806FD191a33493b238B90A4d86);
    address payable public donationWallet = payable(0xf1214dBF1D1285D293604601154327A78580E6A4);
    address public immutable deadAddress = 0x000000000000000000000000000000000000dEaD;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isWalletLimitExempt;
    mapping(address => bool) public isTxLimitExempt;
    mapping(address => bool) public isMarketPair;
    mapping(address => bool) private _isBlacklisted;

    mapping(address => address) public referrer;
    mapping(address => uint256) private _lastTxTime;

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

    uint256 public maxGasPrice = 100 * 10**9; // 100 Gwei
    uint256 public txCooldownTime = 60; // 60 seconds cooldown between transactions

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapPair;

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    bool public checkWalletLimit = true;

    // Ownership management
    address private _owner;
    address private _pendingOwner;
    bool public ownershipTransferredToSafe = false;
    uint256 public timelockDuration = 1 days; // 1-day timelock for critical functions
    mapping(bytes32 => uint256) public timelockFunctions;

    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiquidity);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferInitiated(address indexed previousOwner, address indexed newOwner);

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    modifier antiBot(address sender) {
        require(block.timestamp - _lastTxTime[sender] >= txCooldownTime, "Cooldown: Please wait before sending again");
        _;
        _lastTxTime[sender] = block.timestamp;
    }

    modifier notBlacklisted(address account) {
        require(!_isBlacklisted[account], "This address is blacklisted");
        _;
    }

    modifier ensureGasPrice() {
        require(tx.gasprice <= maxGasPrice, "Gas price exceeds limit");
        _;
    }

    modifier timelockedFunction(bytes32 functionHash) {
        require(block.timestamp >= timelockFunctions[functionHash], "Function is timelocked");
        _;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    constructor() {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E); // Mainnet Uniswap Router Address
        uniswapPair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;
        _allowances[address(this)][address(uniswapV2Router)] = _totalSupply;

        _owner = _msgSender(); // Set deployer as the initial owner

        isExcludedFromFee[address(this)] = true;
        isWalletLimitExempt[address(uniswapPair)] = true;
        isWalletLimitExempt[address(this)] = true;
        isTxLimitExempt[address(this)] = true;

        isMarketPair[address(uniswapPair)] = true;

        totalTaxIfBuying = buyLiquidityFee.add(buyMarketingFee).add(buyTeamFee).add(buyDonationFee);
        totalTaxIfSelling = sellLiquidityFee.add(sellMarketingFee).add(sellTeamFee).add(sellDonationFee);
        totalDistributionShares = totalLiquidityShare.add(totalMarketingShare).add(totalTeamShare).add(totalDonationShare);

        _balances[_msgSender()] = _totalSupply;
        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    // Function to transfer ownership to Gnosis Safe (timelocked)
    function transferOwnershipToSafe() external onlyOwner timelockedFunction(keccak256("transferOwnershipToSafe")) {
        require(!ownershipTransferredToSafe, "Ownership is already transferred to Safe and cannot be reverted");
        transferOwnership(0xDD5F797E224014Ac85e2A6AD1420Ac0e8d424574); // Gnosis Safe address
        ownershipTransferredToSafe = true;
    }

    // Timelock initiation for functions
    function initiateTimelockedFunction(bytes32 functionHash) external onlyOwner {
        timelockFunctions[functionHash] = block.timestamp + timelockDuration;
    }

    // Basic ERC20 Functions
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

    function transfer(address recipient, uint256 amount) public override notBlacklisted(_msgSender()) antiBot(_msgSender()) ensureGasPrice returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        rewardReferrer(recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override notBlacklisted(sender) antiBot(sender) ensureGasPrice returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        rewardReferrer(recipient, amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    // Ownership Transfer Functions
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _pendingOwner = newOwner;
        emit OwnershipTransferInitiated(_owner, newOwner);
    }

    function confirmOwnership() public {
        require(_msgSender() == _pendingOwner, "Ownable: only the pending owner can confirm");
        emit OwnershipTransferred(_owner, _pendingOwner);
        _owner = _pendingOwner;
        _pendingOwner = address(0);
    }

    // Taxes and Fee Settings
    uint256 public constant MAX_BUY_TAX = 10; // Max 10% buy tax
    uint256 public constant MAX_SELL_TAX = 10; // Max 10% sell tax

    function setBuyTaxes(uint256 newLiquidityFee, uint256 newMarketingFee, uint256 newTeamFee, uint256 newDonationFee) external onlyOwner timelockedFunction(keccak256("setBuyTaxes")) {
        require(newLiquidityFee + newMarketingFee + newTeamFee + newDonationFee <= MAX_BUY_TAX, "Buy taxes exceed limit");
        buyLiquidityFee = newLiquidityFee;
        buyMarketingFee = newMarketingFee;
        buyTeamFee = newTeamFee;
        buyDonationFee = newDonationFee;
        totalTaxIfBuying = buyLiquidityFee.add(buyMarketingFee).add(buyTeamFee).add(buyDonationFee);
    }

    function setSellTaxes(uint256 newLiquidityFee, uint256 newMarketingFee, uint256 newTeamFee, uint256 newDonationFee) external onlyOwner timelockedFunction(keccak256("setSellTaxes")) {
        require(newLiquidityFee + newMarketingFee + newTeamFee + newDonationFee <= MAX_SELL_TAX, "Sell taxes exceed limit");
        sellLiquidityFee = newLiquidityFee;
        sellMarketingFee = newMarketingFee;
        sellTeamFee = newTeamFee;
        sellDonationFee = newDonationFee;
        totalTaxIfSelling = sellLiquidityFee.add(sellMarketingFee).add(sellTeamFee).add(sellDonationFee);
    }

    // Wallet Limit and Max Transaction
    function enableDisableWalletLimit(bool newValue) external onlyOwner {
        checkWalletLimit = newValue;
    }

    function setMaxTxAmount(uint256 maxTxAmount) external onlyOwner {
        _maxTxAmount = maxTxAmount;
    }

    function setNumTokensBeforeSwap(uint256 newLimit) external onlyOwner {
        minimumTokensBeforeSwap = newLimit;
    }

    // Swap and Liquify
    function _transfer(address sender, address recipient, uint256 amount) private {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount <= _maxTxAmount || isTxLimitExempt[sender], "Transfer amount exceeds the maxTxAmount.");

        uint256 contractTokenBalance = balanceOf(address(this));
        bool overMinTokenBalance = contractTokenBalance >= minimumTokensBeforeSwap;

        if (overMinTokenBalance && !inSwapAndLiquify && !isMarketPair[sender] && swapAndLiquifyEnabled) {
            if (contractTokenBalance > minimumTokensBeforeSwap) {
                contractTokenBalance = minimumTokensBeforeSwap;
            }
            swapAndLiquify(contractTokenBalance);
        }

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        uint256 finalAmount = (isExcludedFromFee[sender] || isExcludedFromFee[recipient]) ? amount : takeFee(sender, recipient, amount);
        if (checkWalletLimit && !isWalletLimitExempt[recipient]) {
            require(balanceOf(recipient).add(finalAmount) <= _walletMax, "Wallet limit exceeded");
        }

        _balances[recipient] = _balances[recipient].add(finalAmount);
        emit Transfer(sender, recipient, finalAmount);
    }

    function swapAndLiquify(uint256 tokens) private lockTheSwap {
        uint256 halfLiquidity = tokens.div(2);
        uint256 otherHalf = tokens.sub(halfLiquidity);

        uint256 initialBalance = address(this).balance;
        swapTokensForEth(otherHalf);
        uint256 newBalance = address(this).balance.sub(initialBalance);

        addLiquidity(halfLiquidity, newBalance);
        emit SwapAndLiquify(otherHalf, newBalance, halfLiquidity);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, 
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            _owner,
            block.timestamp
        );
    }

    // Fee Logic
    function takeFee(address sender, address recipient, uint256 amount) private returns (uint256) {
        uint256 feeAmount = 0;
        if (isMarketPair[sender]) {
            feeAmount = amount.mul(totalTaxIfBuying).div(100);
        } else if (isMarketPair[recipient]) {
            feeAmount = amount.mul(totalTaxIfSelling).div(100);
        }
        if (feeAmount > 0) {
            _balances[address(this)] = _balances[address(this)].add(feeAmount);
            emit Transfer(sender, address(this), feeAmount);
        }
        return amount.sub(feeAmount);
    }

    // Referral Program
    function setReferrer(address _referrer) external {
        require(referrer[msg.sender] == address(0), "Referrer already set");
        referrer[msg.sender] = _referrer;
    }

    function rewardReferrer(address recipient, uint256 amount) private {
        address ref = referrer[recipient];
        if (ref != address(0)) {
            uint256 reward = amount.div(100); // 1% referral reward
            _balances[ref] = _balances[ref].add(reward);
            emit Transfer(address(this), ref, reward);
        }
    }

    // Blacklisting Malicious Addresses
    function blacklistAddress(address account, bool value) external onlyOwner {
        _isBlacklisted[account] = value;
    }

    // Airdrop Functionality
    function airdropTokens(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner {
        require(recipients.length == amounts.length, "Mismatched arrays");
        for (uint256 i = 0; i < recipients.length; i++) {
            _transfer(_owner, recipients[i], amounts[i]);
        }
    }

    // Burn Functionality (Deflationary Mechanism)
    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    // Vesting Mechanism
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 amountReleased;
        uint256 releaseTime;
    }

    mapping(address => VestingSchedule) public vestingSchedules;

    function setVestingSchedule(address account, uint256 totalAmount, uint256 releaseTime) external onlyOwner {
        vestingSchedules[account] = VestingSchedule(totalAmount, 0, releaseTime);
    }

    function releaseVestedTokens() external {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(block.timestamp >= schedule.releaseTime, "Tokens are still locked");
        require(schedule.amountReleased < schedule.totalAmount, "All tokens have been released");

        uint256 amountToRelease = schedule.totalAmount.sub(schedule.amountReleased);
        _transfer(address(this), msg.sender, amountToRelease);
        schedule.amountReleased = schedule.totalAmount;
    }

    receive() external payable {}
}
