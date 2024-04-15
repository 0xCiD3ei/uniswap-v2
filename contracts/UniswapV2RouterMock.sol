// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interface/IUniswapV2.sol";

contract UniswapV2RouterMock {
    address public uniswapInteraction;

    constructor(address _uniswapInteraction) {
        uniswapInteraction = _uniswapInteraction;
    }

    function getReserves(address pair) external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) {
        return IUniswapV2Pair(pair).getReserves();
    }

}