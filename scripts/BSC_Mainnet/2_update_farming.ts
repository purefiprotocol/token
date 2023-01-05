import { ethers } from "hardhat";
import hre from "hardhat";
import { BigNumber } from "ethers";

const FARMING_PROXY_ADDRESS = "0xc638CbFF653E0feE87E7711B305e5522Bc8C95B2";
const PROXY_ADMIN_ADDRESS = "0x19bB92bfCBde07E6adEEC3eec7d8d21e6f848496";

const NEW_VERIFIER_ADDRESS = "0x62351A3F17a2c4640f45907faB74901a37FaD3C2";

const decimals = BigNumber.from(10).pow(18);

// pool params
const POOL_ID = 0;
const ALLOC_POINT = 100;
const START_BLOCK = 23520000;
const END_BLOCK = 24400000;
const MIN_STAKING_TIME = 604800;
const MAX_STAKING_AMOUNT = BigNumber.from(1_000_000).mul(decimals);
const WITH_UPDATE = false;

const TOKENS_PER_BLOCK = BigNumber.from("284090909090909000");



async function main() {
    const FARMING  = await ethers.getContractFactory("PureFiFarming2");

    // upgrade farming contract
    const newFarmingMasterCopy = await FARMING.deploy();
    await newFarmingMasterCopy.deployed();

    console.log("New Farming Master Copy : ", newFarmingMasterCopy.address);

    const proxy_admin = await ethers.getContractAt("PProxyAdmin", PROXY_ADMIN_ADDRESS);

    console.log("Proxy admin address : ", proxy_admin.address);

    const upgradeTx = await proxy_admin.upgrade(FARMING_PROXY_ADDRESS, newFarmingMasterCopy.address);

    // set new verifier address 

    const farming = await ethers.getContractAt("PureFiFarming2", FARMING_PROXY_ADDRESS);


    console.log("Version : ", await farming.version());

    console.log("set verifier tx");
    const setVerifierTx = await farming.setVerifier(NEW_VERIFIER_ADDRESS);
    console.log("setNewVerifier tx hash : ", setVerifierTx.hash);



    // update pool
    console.log("Update pool tx");
    const updatePoolDataTx = await farming.updatePoolData(
        POOL_ID,
        ALLOC_POINT,
        START_BLOCK,
        END_BLOCK,
        MIN_STAKING_TIME,
        MAX_STAKING_AMOUNT,
        WITH_UPDATE
    );
    console.log("updatePoolData tx hash :", updatePoolDataTx.hash);

    // update tokenPerBlock
        console.log("Tokens per block tx");
    const tokenPerBlockTx = await farming.setTokenPerBlock(TOKENS_PER_BLOCK);
    console.log("tokensPerBlock tx hash :", tokenPerBlockTx.hash);


}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});