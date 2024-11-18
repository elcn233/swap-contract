// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.5.6;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract SwapContract {
    address public owner;
    address public usdoAddress; // USDO contract address
    mapping(address => uint256) public rates; // route to rate
    uint256 public constant RATE_PRECISION = 10**8; // 8 decimal places for precision

    event SwapUsdoToToken(address indexed user, address indexed token, uint256 usdoAmount, uint256 tokenAmount);
    event SwapTokenToUsdo(address indexed user, address indexed token, uint256 tokenAmount, uint256 usdoAmount);
    event SwapTokenToToken(address indexed user, address indexed fromToken, address indexed toToken, uint256 fromAmount, uint256 toAmount);
    event Withdraw(address indexed owner, address indexed asset, uint256 amount);
    event SetRate(address indexed route, uint256 rate);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _usdoAddress) public {
        owner = msg.sender;
        usdoAddress = _usdoAddress;
    }

    function setRate(address route, uint256 rate) public onlyOwner {
        rates[route] = rate;
        emit SetRate(route, rate);
    }

    function getRate(address route) public view returns (uint256) {
        return rates[route];
    }

    function swapUsdoToToken(address tokenAddress, uint256 usdoAmount) public {
        require(rates[tokenAddress] > 0, "Rate not set");
        uint256 tokenAmount = (usdoAmount * rates[tokenAddress]) / RATE_PRECISION;
        IERC20 usdo = IERC20(usdoAddress);
        IERC20 token = IERC20(tokenAddress);
        require(usdo.transferFrom(msg.sender, address(this), usdoAmount), "USDO transfer failed");
        require(token.balanceOf(address(this)) >= tokenAmount, "Insufficient contract token balance");
        require(token.transfer(msg.sender, tokenAmount), "Token transfer failed");
        emit SwapUsdoToToken(msg.sender, tokenAddress, usdoAmount, tokenAmount);
    }

    function swapTokenToUsdo(address tokenAddress, uint256 tokenAmount) public {
        require(rates[tokenAddress] > 0, "Rate not set");
        uint256 usdoAmount = (tokenAmount / rates[tokenAddress]) / RATE_PRECISION;
        IERC20 token = IERC20(tokenAddress);
        IERC20 usdo = IERC20(usdoAddress);
        require(token.transferFrom(msg.sender, address(this), tokenAmount), "Token transfer failed");
        require(usdo.balanceOf(address(this)) >= usdoAmount, "Insufficient contract USDO balance");
        require(usdo.transfer(msg.sender, usdoAmount), "USDO transfer failed");
        emit SwapTokenToUsdo(msg.sender, tokenAddress, tokenAmount, usdoAmount);
    }

    function swapTokenToToken(address fromTokenAddress, address toTokenAddress, uint256 fromAmount) public {
        require(rates[fromTokenAddress] > 0 && rates[toTokenAddress] > 0, "Rate not set");
        uint256 usdoAmount = (fromAmount / rates[fromTokenAddress]) / RATE_PRECISION;
        uint256 toAmount = (usdoAmount * rates[toTokenAddress]) / RATE_PRECISION;
        IERC20 fromToken = IERC20(fromTokenAddress);
        IERC20 toToken = IERC20(toTokenAddress);
        IERC20 usdo = IERC20(usdoAddress);
        require(fromToken.transferFrom(msg.sender, address(this), fromAmount), "From token transfer failed");
        require(usdo.balanceOf(address(this)) >= usdoAmount, "Insufficient contract USDO balance");
        require(usdo.transfer(address(this), usdoAmount), "USDO transfer failed");
        require(toToken.balanceOf(address(this)) >= toAmount, "Insufficient contract token balance");
        require(toToken.transfer(msg.sender, toAmount), "To token transfer failed");
        emit SwapTokenToToken(msg.sender, fromTokenAddress, toTokenAddress, fromAmount, toAmount);
    }

    function withdrawEth(uint256 amount) public onlyOwner {
        require(address(this).balance >= amount, "Insufficient contract ETH balance");
        msg.sender.transfer(amount);
        emit Withdraw(msg.sender, address(0), amount);
    }
    
    function withdrawToken(address tokenAddress, uint256 amount) public onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(address(this)) >= amount, "Insufficient contract token balance");
        require(token.transfer(msg.sender, amount), "Token transfer failed");
        emit Withdraw(msg.sender, tokenAddress, amount);
    }
}
