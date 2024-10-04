// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.27;

// Abstract contract providing information about the current execution context
abstract contract Context {

    // Returns the address of the sender of the transaction
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }

    // Returns the data of the transaction
    function _msgData() internal view virtual returns (bytes memory) {
        this; // Silence state mutability warning without generating bytecode
        return msg.data;
    }
}

// Interface defining the ERC20 standard functions and events
interface IERC20 {

    // Returns the total supply of tokens
    function totalSupply() external view returns (uint256);

    // Returns the token balance of a specific account
    function balanceOf(address account) external view returns (uint256);

    // Transfers tokens to a specified address
    function transfer(address recipient, uint256 amount) external returns (bool);

    // Returns the remaining number of tokens that spender is allowed to spend
    function allowance(address owner, address spender) external view returns (uint256);

    // Approves the passed address to spend the specified amount of tokens
    function approve(address spender, uint256 amount) external returns (bool);

    // Transfers tokens from one address to another using the allowance mechanism
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    // Emitted when tokens are transferred
    event Transfer(address indexed from, address indexed to, uint256 value);

    // Emitted when the allowance of a spender is set by a call to approve
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// Library providing safe mathematical operations to prevent overflows and underflows
library SafeMath {

    // Adds two unsigned integers, reverts on overflow
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    // Subtracts two unsigned integers, reverts on underflow
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    // Subtracts two unsigned integers with a custom error message, reverts on underflow
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    // Multiplies two unsigned integers, reverts on overflow
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    // Divides two unsigned integers, reverts on division by zero
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    // Divides two unsigned integers with a custom error message, reverts on division by zero
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    // Returns the remainder of dividing two unsigned integers, reverts on division by zero
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    // Returns the remainder of dividing two unsigned integers with a custom error message, reverts on division by zero
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// Library with utility functions related to the address type
library Address {

    // Checks if an address is a contract
    function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }

    // Sends Ether to an address, reverts on failure
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    // Performs a low-level call to a target address with provided data
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

    // Performs a low-level call to a target address with provided data and custom error message
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
    }

    // Performs a low-level call to a target address with provided data and Ether value
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    // Performs a low-level call to a target address with provided data, Ether value, and custom error message
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    // Internal function to perform a low-level call with value
    function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errorMessage) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
        if (success) {
            return returndata;
        } else {
            // If the call failed, bubble up the revert reason if present
            if (returndata.length > 0) {
                // Use assembly to revert with the returned data
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

// Contract module which provides a basic access control mechanism, where
// there is an account (an owner) that can be granted exclusive access to
// specific functions.
contract Ownable is Context {
    address private _owner;
    address private _previousOwner;
    uint256 private _lockTime;

    // Event emitted when ownership is transferred
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // Initializes the contract setting the deployer as the initial owner
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    // Returns the address of the current owner
    function owner() public view returns (address) {
        return _owner;
    }   
    
    // Modifier to restrict function access to the owner only
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    
    // Allows the current owner to relinquish control of the contract
    function waiveOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    // Transfers ownership of the contract to a new account (`newOwner`)
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    // Returns the unlock time if the contract is locked
    function getUnlockTime() public view returns (uint256) {
        return _lockTime;
    }
    
    // Returns the current block timestamp
    function getTime() public view returns (uint256) {
        return block.timestamp;
    }

    // Locks the contract for the owner for the specified amount of time
    function lock(uint256 time) public virtual onlyOwner {
        _previousOwner = _owner;
        _owner = address(0);
        _lockTime = block.timestamp + time;
        emit OwnershipTransferred(_owner, address(0));
    }
    
    // Unlocks the contract for the owner after the lock time has passed
    function unlock() public virtual {
        require(_previousOwner == msg.sender, "You don't have permission to unlock");
        require(block.timestamp > _lockTime , "Contract is locked until 7 days");
        emit OwnershipTransferred(_owner, _previousOwner);
        _owner = _previousOwner;
    }
}

// Interface for the Uniswap V2 Factory
interface IUniswapV2Factory {
    // Event emitted when a pair is created
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    // Returns the feeTo address
    function feeTo() external view returns (address);
    // Returns the feeToSetter address
    function feeToSetter() external view returns (address);

    // Returns the pair address for given two tokens
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    // Returns the pair address at a specific index
    function allPairs(uint) external view returns (address pair);
    // Returns the total number of pairs
    function allPairsLength() external view returns (uint);

    // Creates a pair for two tokens
    function createPair(address tokenA, address tokenB) external returns (address pair);

    // Sets the feeTo address
    function setFeeTo(address) external;
    // Sets the feeToSetter address
    function setFeeToSetter(address) external;
}

// Interface for the Uniswap V2 Pair
interface IUniswapV2Pair {
    // Events emitted by the pair
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    // ERC20 metadata functions
    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    
    // ERC20 supply and balance functions
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    // ERC20 approval and transfer functions
    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    // EIP-2612 permit functionality
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    // Allows owner to approve spender to spend value before deadline
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
    
    // Additional events
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

    // Liquidity functions
    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    // Liquidity management functions
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    // Initializes the pair
    function initialize(address, address) external;
}

// Interface for the Uniswap V2 Router01
interface IUniswapV2Router01 {
    // Returns the factory address
    function factory() external pure returns (address);
    // Returns the WETH address
    function WETH() external pure returns (address);

    // Liquidity management functions
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
    
    // Swap functions
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

    // Utility functions
    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

// Interface for the Uniswap V2 Router02, extending Router01 with additional functions
interface IUniswapV2Router02 is IUniswapV2Router01 {
    // Removes liquidity with support for fee on transfer tokens
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

    // Swaps with support for fee on transfer tokens
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

// Main contract implementing the ERC20 token with additional features
contract PRIZEPOT is Context, IERC20, Ownable {
    
    using SafeMath for uint256; // Using SafeMath library for uint256
    using Address for address;  // Using Address library for address type
    
    // Token details
    string private _name = "PRIZE POT";
    string private _symbol = "PRIZEPOT";
    uint8 private _decimals = 9;

    // Wallet addresses for marketing and team funds
    address payable public marketingWalletAddress = payable(0x7184eAC82c0C3F6bcdFD1c28A508dC4a18120b1e); // Marketing Address
    address payable public teamWalletAddress = payable(0xa26809d31cf0cCd4d11C520F84CE9a6Fc4d4bb75); // Team Address
    address public immutable deadAddress = 0x000000000000000000000000000000000000dEaD; // Dead address for burning tokens
    
    // Mapping to keep track of each account's balance
    mapping (address => uint256) _balances;
    // Mapping to keep track of allowances
    mapping (address => mapping (address => uint256)) private _allowances;
    
    // Mappings to manage fee and limit exemptions
    mapping (address => bool) public isExcludedFromFee;
    mapping (address => bool) public isWalletLimitExempt;
    mapping (address => bool) public isTxLimitExempt;
    mapping (address => bool) public isMarketPair;

    // Fees for buying
    uint256 public _buyLiquidityFee = 2;
    uint256 public _buyMarketingFee = 2;
    uint256 public _buyTeamFee = 2;
    
    // Fees for selling
    uint256 public _sellLiquidityFee = 2;
    uint256 public _sellMarketingFee = 2;
    uint256 public _sellTeamFee = 4;

    // Distribution shares
    uint256 public _liquidityShare = 4;
    uint256 public _marketingShare = 4;
    uint256 public _teamShare = 16;

    // Total taxes
    uint256 public _totalTaxIfBuying = 12;
    uint256 public _totalTaxIfSelling = 12;
    uint256 public _totalDistributionShares = 24;

    // Total supply and limits
    uint256 private _totalSupply = 10000000000000 * 10**6 * 10**6 * 10**_decimals;
    uint256 public _maxTxAmount = 10000000000000 * 10**6 * 10**6 * 10**_decimals; 
    uint256 public _walletMax = 10000000000000 * 10**6 * 10**6 * 10**_decimals;
    uint256 private minimumTokensBeforeSwap = 10000000000000 * 10**6 * 10**_decimals; 

    // Uniswap router and pair addresses
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapPair;
    
    // Flags for swap and liquify functionality
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    bool public swapAndLiquifyByLimitOnly = false;
    bool public checkWalletLimit = true;

    // Events related to swap and liquify
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    
    // Events for token and ETH swaps
    event SwapETHForTokens(
        uint256 amountIn,
        address[] path
    );
    
    event SwapTokensForETH(
        uint256 amountIn,
        address[] path
    );
    
    // Modifier to prevent reentrancy during swap and liquify
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }
    
    // Constructor to initialize the contract
    constructor () {
        
        // Initialize Uniswap router with the specified address
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E); 

        // Create a Uniswap pair for this token
        uniswapPair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        // Set the Uniswap router
        uniswapV2Router = _uniswapV2Router;
        // Approve the Uniswap router to spend the total supply of tokens
        _allowances[address(this)][address(uniswapV2Router)] = _totalSupply;

        // Exclude owner and contract from fee
        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;
        
        // Calculate total taxes for buying and selling
        _totalTaxIfBuying = _buyLiquidityFee.add(_buyMarketingFee).add(_buyTeamFee);
        _totalTaxIfSelling = _sellLiquidityFee.add(_sellMarketingFee).add(_sellTeamFee);
        _totalDistributionShares = _liquidityShare.add(_marketingShare).add(_teamShare);

        // Exempt owner, Uniswap pair, and contract from wallet limit
        isWalletLimitExempt[owner()] = true;
        isWalletLimitExempt[address(uniswapPair)] = true;
        isWalletLimitExempt[address(this)] = true;
        
        // Exempt owner and contract from transaction limit
        isTxLimitExempt[owner()] = true;
        isTxLimitExempt[address(this)] = true;

        // Mark the Uniswap pair as a market pair
        isMarketPair[address(uniswapPair)] = true;

        // Assign the total supply to the owner
        _balances[_msgSender()] = _totalSupply;
        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    // Returns the name of the token
    function name() public view returns (string memory) {
        return _name;
    }

    // Returns the symbol of the token
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    // Returns the decimals places of the token
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    // Returns the total supply of the token
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    // Returns the balance of a specific account
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    // Returns the allowance of a spender for a specific owner
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    // Increases the allowance of a spender
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    // Decreases the allowance of a spender
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    // Returns the minimum number of tokens required before a swap can occur
    function minimumTokensBeforeSwapAmount() public view returns (uint256) {
        return minimumTokensBeforeSwap;
    }

    // Approves a spender to spend a specified amount of tokens on behalf of the caller
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    // Internal function to handle approvals
    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address"); // Prevent approving from the zero address
        require(spender != address(0), "ERC20: approve to the zero address"); // Prevent approving to the zero address

        _allowances[owner][spender] = amount; // Set the allowance
        emit Approval(owner, spender, amount); // Emit Approval event
    }

    // Sets the market pair status for a specific account
    function setMarketPairStatus(address account, bool newValue) public onlyOwner {
        isMarketPair[account] = newValue;
    }

    // Sets the transaction limit exemption status for a holder
    function setIsTxLimitExempt(address holder, bool exempt) external onlyOwner {
        isTxLimitExempt[holder] = exempt;
    }
    
    // Sets the fee exemption status for a specific account
    function setIsExcludedFromFee(address account, bool newValue) public onlyOwner {
        isExcludedFromFee[account] = newValue;
    }

    // Sets the buy taxes: liquidity, marketing, and team fees
    function setBuyTaxes(uint256 newLiquidityTax, uint256 newMarketingTax, uint256 newTeamTax) external onlyOwner() {
        _buyLiquidityFee = newLiquidityTax;
        _buyMarketingFee = newMarketingTax;
        _buyTeamFee = newTeamTax;

        _totalTaxIfBuying = _buyLiquidityFee.add(_buyMarketingFee).add(_buyTeamFee);
    }

    // Sets the sell taxes: liquidity, marketing, and team fees
    function setSellTaxes(uint256 newLiquidityTax, uint256 newMarketingTax, uint256 newTeamTax) external onlyOwner() {
        _sellLiquidityFee = newLiquidityTax;
        _sellMarketingFee = newMarketingTax;
        _sellTeamFee = newTeamTax;

        _totalTaxIfSelling = _sellLiquidityFee.add(_sellMarketingFee).add(_sellTeamFee);
    }
    
    // Sets the distribution shares for liquidity, marketing, and team
    function setDistributionSettings(uint256 newLiquidityShare, uint256 newMarketingShare, uint256 newTeamShare) external onlyOwner() {
        _liquidityShare = newLiquidityShare;
        _marketingShare = newMarketingShare;
        _teamShare = newTeamShare;

        _totalDistributionShares = _liquidityShare.add(_marketingShare).add(_teamShare);
    }
    
    // Sets the maximum transaction amount
    function setMaxTxAmount(uint256 maxTxAmount) external onlyOwner() {
        _maxTxAmount = maxTxAmount;
    }

    // Enables or disables the wallet limit
    function enableDisableWalletLimit(bool newValue) external onlyOwner {
       checkWalletLimit = newValue;
    }

    // Sets the wallet limit exemption status for a holder
    function setIsWalletLimitExempt(address holder, bool exempt) external onlyOwner {
        isWalletLimitExempt[holder] = exempt;
    }

    // Sets the maximum number of tokens a wallet can hold
    function setWalletLimit(uint256 newLimit) external onlyOwner {
        _walletMax  = newLimit;
    }

    // Sets the minimum number of tokens before a swap is triggered
    function setNumTokensBeforeSwap(uint256 newLimit) external onlyOwner() {
        minimumTokensBeforeSwap = newLimit;
    }

    // Sets a new marketing wallet address
    function setMarketingWalletAddress(address newAddress) external onlyOwner() {
        marketingWalletAddress = payable(newAddress);
    }

    // Sets a new team wallet address
    function setTeamWalletAddress(address newAddress) external onlyOwner() {
        teamWalletAddress = payable(newAddress);
    }

    // Enables or disables the swap and liquify feature
    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    // Sets whether swap and liquify should occur only when the threshold is reached
    function setSwapAndLiquifyByLimitOnly(bool newValue) public onlyOwner {
        swapAndLiquifyByLimitOnly = newValue;
    }
    
    // Returns the circulating supply (total supply minus the balance of the dead address)
    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply.sub(balanceOf(deadAddress));
    }

    // Transfers Ether to a specified address
    function transferToAddressETH(address payable recipient, uint256 amount) private {
        recipient.transfer(amount);
    }
    
    // Changes the Uniswap router version and updates the pair address accordingly
    function changeRouterVersion(address newRouterAddress) public onlyOwner returns(address newPairAddress) {

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(newRouterAddress); 

        // Get the pair address for the new router
        newPairAddress = IUniswapV2Factory(_uniswapV2Router.factory()).getPair(address(this), _uniswapV2Router.WETH());

        if(newPairAddress == address(0)) // Create if it doesn't exist
        {
            newPairAddress = IUniswapV2Factory(_uniswapV2Router.factory())
                .createPair(address(this), _uniswapV2Router.WETH());
        }

        uniswapPair = newPairAddress; // Set the new pair address
        uniswapV2Router = _uniswapV2Router; // Set the new router address

        // Exempt the new pair from wallet limits and mark it as a market pair
        isWalletLimitExempt[address(uniswapPair)] = true;
        isMarketPair[address(uniswapPair)] = true;
    }

     // Function to receive ETH from UniswapV2Router when swapping
    receive() external payable {}
    
    // Transfers tokens to a specified address
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    // Transfers tokens from one address to another using the allowance mechanism
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        // Decrease the allowance accordingly
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    // Internal function to handle transfers, including fee logic and swap & liquify
    function _transfer(address sender, address recipient, uint256 amount) private returns (bool) {

        require(sender != address(0), "ERC20: transfer from the zero address"); // Prevent transfer from zero address
        require(recipient != address(0), "ERC20: transfer to the zero address"); // Prevent transfer to zero address

        if(inSwapAndLiquify)
        { 
            return _basicTransfer(sender, recipient, amount); // If already in swap and liquify, perform a basic transfer
        }
        else
        {
            if(!isTxLimitExempt[sender] && !isTxLimitExempt[recipient]) {
                require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount."); // Enforce max transaction limit
            }            

            uint256 contractTokenBalance = balanceOf(address(this)); // Get the contract's token balance
            bool overMinimumTokenBalance = contractTokenBalance >= minimumTokensBeforeSwap;
            
            // Check if conditions are met to perform swap and liquify
            if (overMinimumTokenBalance && !inSwapAndLiquify && !isMarketPair[sender] && swapAndLiquifyEnabled) 
            {
                if(swapAndLiquifyByLimitOnly)
                    contractTokenBalance = minimumTokensBeforeSwap; // Use minimum tokens if swap by limit only
                swapAndLiquify(contractTokenBalance); // Perform swap and liquify
            }

            // Subtract the amount from the sender's balance
            _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");

            // Calculate the final amount after deducting fees if applicable
            uint256 finalAmount = (isExcludedFromFee[sender] || isExcludedFromFee[recipient]) ? 
                                         amount : takeFee(sender, recipient, amount);

            // Check wallet limit if applicable
            if(checkWalletLimit && !isWalletLimitExempt[recipient])
                require(balanceOf(recipient).add(finalAmount) <= _walletMax, "Recipient wallet exceeds max limit");

            // Add the final amount to the recipient's balance
            _balances[recipient] = _balances[recipient].add(finalAmount);

            emit Transfer(sender, recipient, finalAmount); // Emit the transfer event
            return true;
        }
    }

    // Performs a basic transfer without taking any fees
    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance"); // Subtract from sender
        _balances[recipient] = _balances[recipient].add(amount); // Add to recipient
        emit Transfer(sender, recipient, amount); // Emit transfer event
        return true;
    }

    // Handles swapping tokens for ETH and adding liquidity
    function swapAndLiquify(uint256 tAmount) private lockTheSwap {
        
        // Calculate tokens for liquidity
        uint256 tokensForLP = tAmount.mul(_liquidityShare).div(_totalDistributionShares).div(2);
        uint256 tokensForSwap = tAmount.sub(tokensForLP); // Remaining tokens to swap

        swapTokensForEth(tokensForSwap); // Swap tokens for ETH
        uint256 amountReceived = address(this).balance; // Get the ETH received from swap

        uint256 totalBNBFee = _totalDistributionShares.sub(_liquidityShare.div(2));
        
        // Calculate amounts for liquidity, team, and marketing
        uint256 amountBNBLiquidity = amountReceived.mul(_liquidityShare).div(totalBNBFee).div(2);
        uint256 amountBNBTeam = amountReceived.mul(_teamShare).div(totalBNBFee);
        uint256 amountBNBMarketing = amountReceived.sub(amountBNBLiquidity).sub(amountBNBTeam);

        if(amountBNBMarketing > 0)
            transferToAddressETH(marketingWalletAddress, amountBNBMarketing); // Transfer to marketing wallet

        if(amountBNBTeam > 0)
            transferToAddressETH(teamWalletAddress, amountBNBTeam); // Transfer to team wallet

        if(amountBNBLiquidity > 0 && tokensForLP > 0)
            addLiquidity(tokensForLP, amountBNBLiquidity); // Add liquidity to Uniswap
    }
    
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

    // Adds liquidity to Uniswap using the specified token and ETH amounts
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(uniswapV2Router), tokenAmount); // Approve token transfer to the router

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

    // Takes fee on transactions based on whether it's a buy or sell
    function takeFee(address sender, address recipient, uint256 amount) internal returns (uint256) {
        
        uint256 feeAmount = 0;
        
        if(isMarketPair[sender]) {
            feeAmount = amount.mul(_totalTaxIfBuying).div(100); // Calculate buy fee
        }
        else if(isMarketPair[recipient]) {
            feeAmount = amount.mul(_totalTaxIfSelling).div(100); // Calculate sell fee
        }
        
        if(feeAmount > 0) {
            _balances[address(this)] = _balances[address(this)].add(feeAmount); // Add fee to contract balance
            emit Transfer(sender, address(this), feeAmount); // Emit transfer event for fee
        }

        return amount.sub(feeAmount); // Return the amount after fee deduction
    }
    
}
