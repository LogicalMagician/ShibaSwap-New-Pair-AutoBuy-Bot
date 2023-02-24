pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IShibaswap {
    function factory() external pure returns (address);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function allPairs(uint256) external view returns (address pair);
    function allPairsLength() external view returns (uint256);
}

interface IShibaPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

contract ShibaswapScanner is Ownable {
    using SafeERC20 for IERC20;

    address public constant shibaswapAddress = 0x9e78b8274e1D6a76a0dBbf90418894DF27cBCEb5;
    uint256 public constant purchaseAmount = 20000000000000000; // 0.02 ETH
    mapping(address => uint256) public balances;

    function scanAndPurchase() external {
        IShibaswap shibaswap = IShibaswap(shibaswapAddress);
        uint256 length = shibaswap.allPairsLength();
        for (uint256 i = 0; i < length; i++) {
            address pairAddress = shibaswap.allPairs(i);
            IShibaPair pair = IShibaPair(pairAddress);
            (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
            if (reserve0 == 0 || reserve1 == 0) {
                continue;
            }
            address tokenToBuy = reserve0 > reserve1 ? pair.token0() : pair.token1();
            IERC20(tokenToBuy).safeApprove(shibaswapAddress, 0);
            IERC20(tokenToBuy).safeApprove(shibaswapAddress, type(uint256).max);
            IShibaswap(shibaswapAddress).swapExactETHForTokens{value: purchaseAmount}(0, getPathForETHToToken(tokenToBuy), address(this), block.timestamp + 60);
            balances[tokenToBuy] += IERC20(tokenToBuy).balanceOf(address(this));
        }
    }

    function withdraw(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        payable(owner()).transfer(amount);
    }

    function sweep(IERC20 token) external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        token.safeTransfer(owner(), balance);
    }

    function getPathForETHToToken(address token) private view returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = IShibaswap(shibaswapAddress).factory();
        path[1] = token;
        return path;
    }

    receive() external payable {}
}
