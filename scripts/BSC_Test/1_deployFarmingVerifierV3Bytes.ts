import { ethers, upgrades } from "hardhat";
import hre from "hardhat";
import { BigNumber } from "ethers";


const VERIFIER = "0xEe998fdA53Ba2312340708606AED2Cd52Cf441DA";
const ADMIN = "0x5c8C756c8379d7189F0a773D7459f54F792aE270";
const TOKEN = "0x416E6E78208a3066B6f28D22d033c8d25625d266";
const TOKENS_PER_BLOCK = BigNumber.from("308641975308642000");
const START_BLOCK = 24902296;
const END_BLOCK = START_BLOCK + 10_000_000;
const NULL_ADDRESS = "0x0000000000000000000000000000000000000000";
const decimals = BigNumber.from(10).pow(18);

async function main() {

    const FARMING = await ethers.getContractFactory("PureFiFarming2");
    const PROXY_ADMIN = await ethers.getContractFactory("PProxyAdmin");
    const PROXY  = await ethers.getContractFactory("PPRoxy");


    const proxy_admin = await PROXY_ADMIN.deploy();
    await proxy_admin.deployed();

    console.log("Proxy Admin : ", proxy_admin.address);

    const farmingMasterCopy = await FARMING.deploy();
    await farmingMasterCopy.deployed();
    console.log("Master Copy address : ",  farmingMasterCopy.address);


    const farming_proxy = await PROXY.deploy(farmingMasterCopy.address, proxy_admin.address, "0x");
    await farming_proxy.deployed();

    console.log("Farming proxy : ", farming_proxy.address);


    const farming = await ethers.getContractAt("PureFiFarming2", farming_proxy.address);

    await farming.initialize(
        ADMIN,
        TOKEN,
        TOKENS_PER_BLOCK,
        START_BLOCK + 10,
        NULL_ADDRESS,
        VERIFIER,
    );

    await farming.addPool(
        100,
        TOKEN,
        START_BLOCK,
        END_BLOCK,
        100,
        BigNumber.from(100000).mul(decimals),
        true
    );


}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});