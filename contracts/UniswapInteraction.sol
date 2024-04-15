// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interface/IUniswapV2.sol";

contract UniswapInteraction {

    address private constant UNISWAP_ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant WETH = 
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant UNISWAP_FACTORY =
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    event AddedLiquidity(
        string message,
        uint amountTokenA,
        uint amountTokenB,
        uint liquidity
    );
    event RemovedLiquidity(
        string message,
        uint amountTokenA,
        uint amountTokenB
    );

    // Swaps an amount of tokens for another using the Uniswap V2 router.
    function performSwap(
        address tokenFrom,
        address tokenTo,
        uint256 amountFrom,
        uint256 minAmountTo,
        address recipient
    ) external {
        IERC20(tokenFrom).transferFrom(msg.sender, address(this), amountFrom);
        IERC20(tokenFrom).approve(UNISWAP_ROUTER, amountFrom);

        address[] memory path;
        if (tokenFrom == WETH || tokenTo == WETH) {
            path = new address[](2);
            path[0] = tokenFrom;
            path[1] = tokenTo;
        } else {
            path = new address[](3);
            path[0] = tokenFrom;
            path[1] = WETH;
            path[2] = tokenTo;
        }

        IUniswapV2Router(UNISWAP_ROUTER).swapExactTokensForTokens(
            amountFrom,
            minAmountTo,
            path,
            recipient,
            block.timestamp
        );
    }

    //Calculates the minimum amount of output tokens that will be received for a given input amount of tokens.
    function getMinOutputAmount(
        address tokenFrom,
        address tokenTo,
        uint256 amountFrom
    ) external view returns (uint256) {
        address[] memory path;
        if (tokenFrom == WETH || tokenTo == WETH) {
            path = new address[](2);
            path[0] = tokenFrom;
            path[1] = tokenTo;
        } else {
            path = new address[](3);
            path[0] = tokenFrom;
            path[1] = WETH;
            path[2] = tokenTo;
        }

        uint256[] memory outputAmounts = IUniswapV2Router(UNISWAP_ROUTER)
            .getAmountsOut(amountFrom, path);

        return outputAmounts[path.length - 1];
    }

    // Adds liquidity to the Uniswap v2 exchange.
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountA,
        uint amountB
    ) external {
        // Transfer tokens to the contract address
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);
        // Approve the Uniswap router to spend the tokens
        IERC20(tokenA).approve(UNISWAP_ROUTER, amountA);
        IERC20(tokenB).approve(UNISWAP_ROUTER, amountB);
        // Add liquidity to the Uniswap exchange
        (
            uint amountTokenA,
            uint amountTokenB,
            uint liquidity
        ) = IUniswapV2Router(UNISWAP_ROUTER).addLiquidity(
                tokenA,
                tokenB,
                amountA,
                amountB,
                1,
                1,
                address(this),
                block.timestamp
            );
        // Emit an event indicating the success of the operation
        emit AddedLiquidity(
            "liquidity added successfully",
            amountTokenA,
            amountTokenB,
            liquidity
        );
    }

    // Removes liquidity from the Uniswap v2 exchange.
    function removeLiquidity(address tokenA, address tokenB) external {
        // Get the pair address for the tokens
        address pair = IUniswapV2Factory(UNISWAP_FACTORY).getPair(
            tokenA,
            tokenB
        );
        // Approve the Uniswap router to spend the liquidity tokens
        uint liquidity = IERC20(pair).balanceOf(address(this));
        IERC20(pair).approve(UNISWAP_ROUTER, liquidity);
        // Remove liquidity from the Uniswap exchange
        (uint amountTokenA, uint amountTokenB) = IUniswapV2Router(
            UNISWAP_ROUTER
        ).removeLiquidity(
                tokenA,
                tokenB,
                liquidity,
                1,
                1,
                address(this),
                block.timestamp
            );
        // Emit an event indicating the success of the operation
        emit RemovedLiquidity(
            "liquidity removed successfully",
            amountTokenA,
            amountTokenB
        );
    }

    // Calculates the square root of a given number
    function _calculateSqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    // Calculates the optimal swap amount of Token A for Token B based on the current reserves of the Uniswap pool.
    function calculateOptimalSwapAmount(
        uint r,
        uint a
    ) public pure returns (uint) {
        return
            (_calculateSqrt(r * ((r * 3988009) + (a * 3988000))) - (r * 1997)) / 1994;
    }

    //Adds liquidity to a Uniswap pool in an optimal way.
    function addOptimalLiquidity(
        address _tokenA,
        uint _amountA,
        address _tokenB
    ) external {
        require(
            _tokenA == WETH || _tokenB == WETH,
            "Token A or B must be WETH"
        );

        IERC20(_tokenA).transferFrom(msg.sender, address(this), _amountA);

        address pair = IUniswapV2Factory(UNISWAP_FACTORY).getPair(
            _tokenA,
            _tokenB
        );
        (uint reserve0, uint reserve1, ) = IUniswapV2Pair(pair).getReserves();

        uint swapAmount;
        if (IUniswapV2Pair(pair).token0() == _tokenA) {
            swapAmount = calculateOptimalSwapAmount(reserve0, _amountA);
        } else {
            swapAmount = calculateOptimalSwapAmount(reserve1, _amountA);
        }

        _executeTokenSwap(_tokenA, _tokenB, swapAmount);
        _provideLiquidity(_tokenA, _tokenB);
    }

    // Adds liquidity to a Uniswap pool in a suboptimal way.
    function addSubOptimalLiquidity(
        address _tokenA,
        uint _amountA,
        address _tokenB
    ) external {
        IERC20(_tokenA).transferFrom(msg.sender, address(this), _amountA);

        uint halfAmountA = _amountA / 2;
        _executeTokenSwap(_tokenA, _tokenB, halfAmountA);
        _provideLiquidity(_tokenA, _tokenB);
    }

    // Executes a token swap on Uniswap.
    function _executeTokenSwap(
        address _from,
        address _to,
        uint _amount
    ) internal {
        IERC20(_from).approve(UNISWAP_ROUTER, _amount);

        address[] memory path = new address[](2);
        path[0] = _from;
        path[1] = _to;

        IUniswapV2Router(UNISWAP_ROUTER).swapExactTokensForTokens(
            _amount,
            1,
            path,
            address(this),
            block.timestamp
        );
    }

    // Provides liquidity to a Uniswap pool.
    function _provideLiquidity(address _tokenA, address _tokenB) internal {
        uint balA = IERC20(_tokenA).balanceOf(address(this));
        uint balB = IERC20(_tokenB).balanceOf(address(this));
        IERC20(_tokenA).approve(UNISWAP_ROUTER, balA);
        IERC20(_tokenB).approve(UNISWAP_ROUTER, balB);

        IUniswapV2Router(UNISWAP_ROUTER).addLiquidity(
            _tokenA,
            _tokenB,
            balA,
            balB,
            0,
            0,
            address(this),
            block.timestamp
        );
    }

    // Retrieves the pair address of Token A and Token B in the Uniswap factory.
    function retrievePair(
        address _tokenA,
        address _tokenB
    ) external view returns (address) {
        return IUniswapV2Factory(UNISWAP_FACTORY).getPair(_tokenA, _tokenB);
    }
}