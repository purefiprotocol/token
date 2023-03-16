import { ethers, upgrades } from "hardhat";
import hre from "hardhat";
import { BigNumber } from "ethers";


const ADMIN = "";
const REWARD_TOKEN = "";
const TOKENS_PER_BLOCK = "";
const NO_REWARD_CLAIMS_UNTIL = "";
const TOKEN_BUYER = "";
const VERIFIER = "";


const ALLOCATION_POINT = "";
const LP_TOKEN_ADDRESS = "";
const START_BLOCK = "";
const END_BLOCK = "";
const MIN_STAKING_TIME = "";
const MAX_STAKING_AMOUNT = "";
const WITH_UPDATE = false;



async function main() {

    const PPROXY = await ethers.getContractFactory("PPRoxy");
    const PPROXY_ADMIN = await ethers.getContractFactory("PProxyAdmin");

    const FARMING = await ethers.getContractFactory("PureFiFarming2");

    // DEPLOY PPROXY_ADMIN //

    const proxy_admin = await PPROXY_ADMIN.deploy();
    await proxy_admin.deployed();

    console.log("proxy_admin address : ", proxy_admin.address);

    // DEPLOY FARMING //
    const farmingMasterCopy = await FARMING.deploy();
    await farmingMasterCopy.deployed();

    console.log("Farming master copy : ", farmingMasterCopy.address);

    const farming_proxy = await PPROXY.deploy(farmingMasterCopy.address, proxy_admin.address, "0x");
    await farming_proxy.deployed();

    console.log("Farming proxy address : ", farming_proxy.address);

    // initialize farming
    const farming = await ethers.getContractAt("PureFiFarming2", farming_proxy.address);
    await farming.initialize(
        ADMIN,
        REWARD_TOKEN, 
        TOKENS_PER_BLOCK,
        NO_REWARD_CLAIMS_UNTIL,
        TOKEN_BUYER,
        VERIFIER
    );

    // add pool 

    await farming.addPool(
        ALLOCATION_POINT,
        LP_TOKEN_ADDRESS,
        START_BLOCK,
        END_BLOCK,
        MIN_STAKING_TIME,
        MAX_STAKING_AMOUNT,
        WITH_UPDATE
    );

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});