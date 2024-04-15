import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const UniswapModule = buildModule("UniswapModule", (m) => {
    const uniswapInteraction = m.contract("UniswapInteraction");

    return { uniswapInteraction };
})

export default UniswapModule;