// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.27;

/*
    Context, IERC20, SafeMath, Address, Ownable, IUniswapV2Factory, IUniswapV2Pair,
    IUniswapV2Router01, and IUniswapV2Router02 contracts/interfaces are included below.
    They are essential for ERC20 functionality, safe mathematical operations, address utilities,
    ownership management, and interactions with Uniswap for liquidity and swapping.
*/

// ------------------- [START OF IMPORTED CONTRACTS & INTERFACES] -------------------

// Context Contract
abstract contract Context {

    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning
        return msg.data;
    }
}

// IERC20 Interface
interface IERC20 {

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address ownerAddr, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed ownerAddr, address indexed spender, uint256 value);
}

// SafeMath Library
library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b);

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// Address Library
library Address {

    function isContract(address account) internal view returns (bool) {
        // EIP-1052: 0x0 for non-existent accounts
        // 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 for accounts without code
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
    }

    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errorMessage) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
        if (success) {
            return returndata;
        } else {
            
            if (returndata.length > 0) {
                // Bubble up the revert reason from the call
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// Ownable Contract
contract Ownable is Context {
    address private _owner;
    address private _previousOwner;
    uint256 private _lockTime;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }   
    
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    
    function waiveOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function getUnlockTime() public view returns (uint256) {
        return _lockTime;
    }
    
    function getTime() public view returns (uint256) {
        return block.timestamp;
    }

    function lock(uint256 time) public virtual onlyOwner {
        _previousOwner = _owner;
        _owner = address(0);
        _lockTime = block.timestamp + time;
        emit OwnershipTransferred(_owner, address(0));
    }
    
    function unlock() public virtual {
        require(_previousOwner == msg.sender, "You don't have permission to unlock");
        require(block.timestamp > _lockTime , "Contract is locked until the specified time");
        emit OwnershipTransferred(_owner, _previousOwner);
        _owner = _previousOwner;
    }
}

// IUniswapV2Factory Interface
interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

// IUniswapV2Pair Interface
interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address ownerAddr) external view returns (uint);
    function allowance(address ownerAddr, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address ownerAddr) external view returns (uint);

    function permit(address ownerAddr, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
    
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

// IUniswapV2Router01 Interface
interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    // Liquidity Functions
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    
    // Swap Functions
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    // Utility Functions
    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

// IUniswapV2Router02 Interface
interface IUniswapV2Router02 is IUniswapV2Router01 {
    // Additional liquidity functions
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    // Additional swap functions
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

// ------------------- [END OF IMPORTED CONTRACTS & INTERFACES] -------------------

// Main ERC20 Token Contract with Integrated Lottery System
contract PrizePot is Context, IERC20, Ownable {
    
    using SafeMath for uint256;
    using Address for address;
    
    // ERC20 Token Details
    string private _name = "PRIZE POT";
    string private _symbol = "PPOT";
    uint8 private _decimals = 9;

    // Wallet Addresses
    address payable public marketingWalletAddress = payable(0x7184eAC82c0C3F6bcdFD1c28A508dC4a18120b1e); // Marketing Address
    address payable public teamWalletAddress = payable(0xa26809d31cf0cCd4d11C520F84CE9a6Fc4d4bb75); // Team Address
    address public immutable deadAddress = 0x000000000000000000000000000000000000dEaD;
    
    // Balances and Allowances
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    
    // Fee Exclusions and Limits
    mapping (address => bool) public isExcludedFromFee;
    mapping (address => bool) public isWalletLimitExempt;
    mapping (address => bool) public isTxLimitExempt;
    mapping (address => bool) public isMarketPair;

    // Fee Structure
    uint256 public _buyLiquidityFee = 2;
    uint256 public _buyMarketingFee = 2;
    uint256 public _buyTeamFee = 2;
    uint256 public _buyLotteryFee = 1; // Added Lottery Fee for Buy

    uint256 public _sellLiquidityFee = 2;
    uint256 public _sellMarketingFee = 2;
    uint256 public _sellTeamFee = 4;
    uint256 public _sellLotteryFee = 1; // Added Lottery Fee for Sell

    uint256 public _liquidityShare = 4;
    uint256 public _marketingShare = 4;
    uint256 public _teamShare = 16;
    uint256 public _lotteryShare = 4; // Added Lottery Share

    uint256 public _totalTaxIfBuying = 7; // Total Buy Tax (2+2+2+1)
    uint256 public _totalTaxIfSelling = 9; // Total Sell Tax (2+2+4+1)
    uint256 public _totalDistributionShares = 28; // Total Distribution Shares (4+4+16+4)

    // Adjusted Total Supply and Related Parameters
    uint256 private _totalSupply = 1_000_000_000 * 10**_decimals; // 1,000,000,000 PPOT
    uint256 public _maxTxAmount = 10_000_000 * 10**_decimals; // 1% of total supply
    uint256 public _walletMax = 20_000_000 * 10**_decimals; // 2% of total supply
    uint256 private minimumTokensBeforeSwap = 500_000 * 10**_decimals; // 0.05% of total supply

    // Uniswap Router and Pair
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapPair;
    
    // Swap and Liquify
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    bool public swapAndLiquifyByLimitOnly = false;
    bool public checkWalletLimit = true;

    // Lottery Variables
    uint256 public lotteryPool;
    address[] public lotteryParticipants;
    uint256 public lastLotteryTime;
    uint256 public lotteryInterval = 24 hours; // Lottery interval (e.g., every 24 hours)
    address public lastWinner;

    // Events
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiquidity
    );
    
    event SwapETHForTokens(
        uint256 amountIn,
        address[] path
    );
    
    event SwapTokensForETH(
        uint256 amountIn,
        address[] path
    );
    
    event LotteryEntry(address indexed participant);
    event LotteryWinner(address indexed winner, uint256 amount);
    
    // Modifier to prevent reentrancy during swap and liquify
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }
    
    constructor () {
        
        // Initialize Uniswap Router (Mainnet Address: 0x10ED43C718714eb63d5aA57B78B54704E256024E)
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x10ED43C718714eb63d5aA57B78B54704E256024E
        ); 

        // Create a Uniswap pair for this token
        uniswapPair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;
        _allowances[address(this)][address(uniswapV2Router)] = _totalSupply;

        // Exclude owner and contract from fee
        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;
        
        // Calculate total taxes
        _totalTaxIfBuying = _buyLiquidityFee.add(_buyMarketingFee).add(_buyTeamFee).add(_buyLotteryFee);
        _totalTaxIfSelling = _sellLiquidityFee.add(_sellMarketingFee).add(_sellTeamFee).add(_sellLotteryFee);
        _totalDistributionShares = _liquidityShare.add(_marketingShare).add(_teamShare).add(_lotteryShare);

        // Exempt from wallet limit
        isWalletLimitExempt[owner()] = true;
        isWalletLimitExempt[address(uniswapPair)] = true;
        isWalletLimitExempt[address(this)] = true;
        
        // Exempt from transaction limit
        isTxLimitExempt[owner()] = true;
        isTxLimitExempt[address(this)] = true;

        // Mark Uniswap pair as market pair
        isMarketPair[address(uniswapPair)] = true;

        _balances[_msgSender()] = _totalSupply;
        emit Transfer(address(0), _msgSender(), _totalSupply);

        // Initialize lottery
        lastLotteryTime = block.timestamp;
    }

    // ------------------- [START OF ERC20 STANDARD FUNCTIONS] -------------------

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

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function minimumTokensBeforeSwapAmount() public view returns (uint256) {
        return minimumTokensBeforeSwap;
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    // Internal approve function
    function _approve(address ownerAddr, address spender, uint256 amount) private {
        require(ownerAddr != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[ownerAddr][spender] = amount;
        emit Approval(ownerAddr, spender, amount);
    }

    // ------------------- [END OF ERC20 STANDARD FUNCTIONS] -------------------

    // ------------------- [START OF ADMIN FUNCTIONS] -------------------

    // Set Market Pair Status
    function setMarketPairStatus(address account, bool newValue) public onlyOwner {
        isMarketPair[account] = newValue;
    }

    // Exempt from Transaction Limit
    function setIsTxLimitExempt(address holder, bool exempt) external onlyOwner {
        isTxLimitExempt[holder] = exempt;
    }
    
    // Exclude or Include from Fee
    function setIsExcludedFromFee(address account, bool newValue) public onlyOwner {
        isExcludedFromFee[account] = newValue;
    }

    // Set Buy Taxes
    function setBuyTaxes(uint256 newLiquidityTax, uint256 newMarketingTax, uint256 newTeamTax, uint256 newLotteryTax) external onlyOwner() {
        _buyLiquidityFee = newLiquidityTax;
        _buyMarketingFee = newMarketingTax;
        _buyTeamFee = newTeamTax;
        _buyLotteryFee = newLotteryTax;

        _totalTaxIfBuying = _buyLiquidityFee.add(_buyMarketingFee).add(_buyTeamFee).add(_buyLotteryFee);
    }

    // Set Sell Taxes
    function setSellTaxes(uint256 newLiquidityTax, uint256 newMarketingTax, uint256 newTeamTax, uint256 newLotteryTax) external onlyOwner() {
        _sellLiquidityFee = newLiquidityTax;
        _sellMarketingFee = newMarketingTax;
        _sellTeamFee = newTeamTax;
        _sellLotteryFee = newLotteryTax;

        _totalTaxIfSelling = _sellLiquidityFee.add(_sellMarketingFee).add(_sellTeamFee).add(_sellLotteryFee);
    }
    
    // Set Distribution Shares
    function setDistributionSettings(uint256 newLiquidityShare, uint256 newMarketingShare, uint256 newTeamShare, uint256 newLotteryShare) external onlyOwner() {
        _liquidityShare = newLiquidityShare;
        _marketingShare = newMarketingShare;
        _teamShare = newTeamShare;
        _lotteryShare = newLotteryShare;

        _totalDistributionShares = _liquidityShare.add(_marketingShare).add(_teamShare).add(_lotteryShare);
    }
    
    // Set Maximum Transaction Amount
    function setMaxTxAmount(uint256 maxTxAmount) external onlyOwner() {
        _maxTxAmount = maxTxAmount;
    }

    // Enable or Disable Wallet Limit
    function enableDisableWalletLimit(bool newValue) external onlyOwner() {
       checkWalletLimit = newValue;
    }

    // Exempt from Wallet Limit
    function setIsWalletLimitExempt(address holder, bool exempt) external onlyOwner() {
        isWalletLimitExempt[holder] = exempt;
    }

    // Set Wallet Limit
    function setWalletLimit(uint256 newLimit) external onlyOwner() {
        _walletMax  = newLimit;
    }

    // Set Minimum Tokens Before Swap
    function setNumTokensBeforeSwap(uint256 newLimit) external onlyOwner() {
        minimumTokensBeforeSwap = newLimit;
    }

    // Set Marketing Wallet Address
    function setMarketingWalletAddress(address newAddress) external onlyOwner() {
        marketingWalletAddress = payable(newAddress);
    }

    // Set Team Wallet Address
    function setTeamWalletAddress(address newAddress) external onlyOwner() {
        teamWalletAddress = payable(newAddress);
    }

    // Enable or Disable Swap and Liquify
    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    // Set Swap and Liquify by Limit Only
    function setSwapAndLiquifyByLimitOnly(bool newValue) public onlyOwner {
        swapAndLiquifyByLimitOnly = newValue;
    }
    
    // Change Uniswap Router Version
    function changeRouterVersion(address newRouterAddress) public onlyOwner() returns(address newPairAddress) {

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(newRouterAddress); 

        newPairAddress = IUniswapV2Factory(_uniswapV2Router.factory()).getPair(address(this), _uniswapV2Router.WETH());

        if(newPairAddress == address(0)) // Create if doesn't exist
        {
            newPairAddress = IUniswapV2Factory(_uniswapV2Router.factory())
                .createPair(address(this), _uniswapV2Router.WETH());
        }

        uniswapPair = newPairAddress; // Set new pair address
        uniswapV2Router = _uniswapV2Router; // Set new router address

        isWalletLimitExempt[address(uniswapPair)] = true;
        isMarketPair[address(uniswapPair)] = true;
    }

    // ------------------- [END OF ADMIN FUNCTIONS] -------------------

    // ------------------- [START OF ERC20 TRANSFER FUNCTIONS] -------------------

    // To receive ETH from Uniswap V2 Router when swapping
    receive() external payable {}

    // ERC20 Transfer Function
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    // ERC20 TransferFrom Function
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    // Internal Transfer Function with Lottery Integration
    function _transfer(address sender, address recipient, uint256 amount) private returns (bool) {

        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        // If the contract is performing a swap and liquify, execute a basic transfer
        if(inSwapAndLiquify)
        { 
            return _basicTransfer(sender, recipient, amount); 
        }
        else
        {
            // Check transaction limit
            if(!isTxLimitExempt[sender] && !isTxLimitExempt[recipient]) {
                require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
            }            

            uint256 contractTokenBalance = balanceOf(address(this));
            bool overMinimumTokenBalance = contractTokenBalance >= minimumTokensBeforeSwap;
            
            if (overMinimumTokenBalance && !inSwapAndLiquify && !isMarketPair[sender] && swapAndLiquifyEnabled) 
            {
                if(swapAndLiquifyByLimitOnly)
                    contractTokenBalance = minimumTokensBeforeSwap;
                swapAndLiquify(contractTokenBalance);    
            }

            _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");

            uint256 finalAmount = (isExcludedFromFee[sender] || isExcludedFromFee[recipient]) ? 
                                         amount : takeFee(sender, recipient, amount);

            if(checkWalletLimit && !isWalletLimitExempt[recipient])
                require(balanceOf(recipient).add(finalAmount) <= _walletMax, "Recipient exceeds wallet limit");

            _balances[recipient] = _balances[recipient].add(finalAmount);

            emit Transfer(sender, recipient, finalAmount);

            // Handle Lottery Entries
            if(isMarketPair[sender] || isMarketPair[recipient]) {
                // Add lottery entry
                _addLotteryEntry(recipient);

                // Attempt to select a winner if interval has passed
                if(block.timestamp >= lastLotteryTime + lotteryInterval) {
                    selectWinner();
                }
            }

            return true;
        }
    }

    // Basic Transfer Function without Fees
    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
        return true;
    }

    // ------------------- [END OF ERC20 TRANSFER FUNCTIONS] -------------------

    // ------------------- [START OF SWAP AND LIQUIFY FUNCTIONS] -------------------

    // Swap and Liquify Function
    function swapAndLiquify(uint256 tAmount) private lockTheSwap {
        
        uint256 tokensForLP = tAmount.mul(_liquidityShare).div(_totalDistributionShares).div(2);
        uint256 tokensForSwap = tAmount.sub(tokensForLP);

        swapTokensForEth(tokensForSwap);
        uint256 amountReceived = address(this).balance;

        uint256 totalBNBFee = _totalDistributionShares.sub(_liquidityShare.div(2));
        
        uint256 amountBNBLiquidity = amountReceived.mul(_liquidityShare).div(totalBNBFee).div(2);
        uint256 amountBNBMarketing = amountReceived.mul(_marketingShare).div(totalBNBFee);
        uint256 amountBNBTeam = amountReceived.mul(_teamShare).div(totalBNBFee);
        uint256 amountBNBLottery = amountReceived.mul(_lotteryShare).div(totalBNBFee);

        if(amountBNBMarketing > 0)
            transferToAddressETH(marketingWalletAddress, amountBNBMarketing);

        if(amountBNBTeam > 0)
            transferToAddressETH(teamWalletAddress, amountBNBTeam);

        if(amountBNBLiquidity > 0 && tokensForLP > 0)
            addLiquidity(tokensForLP, amountBNBLiquidity);
        
        if(amountBNBLottery > 0) {
            lotteryPool = lotteryPool.add(amountBNBLottery);
        }
    }
    
    // Swap Tokens for ETH using Uniswap Router
    // Swaps a specified amount of tokens for ETH using Uniswap
    function swapTokensForEth(uint256 tokenAmount) private {
        // Generate the Uniswap pair path of token -> WETH
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount); // Approve the router to spend tokens

        // Make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // Accept any amount of ETH
            path,
            address(this), // The contract
            block.timestamp
        );
        
        emit SwapTokensForETH(tokenAmount, path); // Emit event after swap
    }

    // Add Liquidity to Uniswap
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // Approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // Add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // Slippage is unavoidable
            0, // Slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    // ------------------- [END OF SWAP AND LIQUIFY FUNCTIONS] -------------------

    // ------------------- [START OF FEES FUNCTIONS] -------------------

    // Take Fees from Transactions
    function takeFee(address sender, address recipient, uint256 amount) internal returns (uint256) {
        
        uint256 feeAmount = 0;
        
        if(isMarketPair[sender]) {
            feeAmount = amount.mul(_totalTaxIfBuying).div(100);
        }
        else if(isMarketPair[recipient]) {
            feeAmount = amount.mul(_totalTaxIfSelling).div(100);
        }
        
        if(feeAmount > 0) {
            _balances[address(this)] = _balances[address(this)].add(feeAmount);
            emit Transfer(sender, address(this), feeAmount);
        }

        return amount.sub(feeAmount);
    }

    // ------------------- [END OF FEES FUNCTIONS] -------------------

    // ------------------- [START OF LOTTERY FUNCTIONS] -------------------

    /**
     * @dev Adds a participant to the lottery.
     * Each eligible transaction adds one entry.
     */
    function _addLotteryEntry(address participant) internal {
        lotteryParticipants.push(participant);
        emit LotteryEntry(participant);
    }

    /**
     * @dev Selects a winner if the lottery interval has passed.
     * Can be called by anyone.
     */
    function selectWinner() public {
        require(block.timestamp >= lastLotteryTime + lotteryInterval, "Lottery: Interval not yet passed");
        require(lotteryParticipants.length > 0, "Lottery: No participants");
        require(lotteryPool > 0, "Lottery: No funds to distribute");

        // Pseudo-random number generation (Not secure)
        uint256 randomNumber = uint256(
            keccak256(
                abi.encodePacked(
                    block.difficulty,
                    block.timestamp,
                    lotteryParticipants.length
                )
            )
        );
        uint256 winnerIndex = randomNumber % lotteryParticipants.length;
        address winner = lotteryParticipants[winnerIndex];
        uint256 prize = lotteryPool;

        // Reset lottery pool and participants
        lotteryPool = 0;
        delete lotteryParticipants;
        lastLotteryTime = block.timestamp;

        // Transfer prize to winner
        (bool success, ) = payable(winner).call{value: prize}("");
        require(success, "Lottery: Transfer failed");

        // Record last winner
        lastWinner = winner;

        emit LotteryWinner(winner, prize);
    }

    /**
     * @dev Returns the number of lottery participants.
     */
    function getNumberOfParticipants() public view returns (uint256) {
        return lotteryParticipants.length;
    }

    /**
     * @dev Returns the current lottery pool in ETH.
     */
    function getLotteryPool() public view returns (uint256) {
        return lotteryPool;
    }

    /**
     * @dev Allows the owner to set the lottery interval.
     */
    function setLotteryInterval(uint256 _interval) external onlyOwner {
        require(_interval >= 1 hours, "Lottery: Interval too short");
        lotteryInterval = _interval;
    }

    // ------------------- [END OF LOTTERY FUNCTIONS] -------------------

    // ------------------- [START OF MISSING FUNCTION] -------------------

    /**
     * @dev Transfers ETH to a specified address.
     * @param recipient The address to receive ETH.
     * @param amount The amount of ETH to transfer.
     */
    function transferToAddressETH(address payable recipient, uint256 amount) private {
        require(address(this).balance >= amount, "Transfer: Insufficient ETH balance");
        recipient.transfer(amount);
    }

    // ------------------- [END OF MISSING FUNCTION] -------------------
}

