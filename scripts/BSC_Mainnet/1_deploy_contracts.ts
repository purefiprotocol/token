import { ethers, upgrades } from "hardhat";
import hre from "hardhat";
import { BigNumber } from "ethers";

const ADMIN = "0x1e1Baf37B7C89341DEdd688CE74785A703e2e0E3";
const TOKEN = "0xe2a59D5E33c6540E18aAA46BF98917aC3158Db0D"; // BSC PureFiToken address
const TOKENS_PER_BLOCK = BigNumber.from("308641975308642000");
const NO_REWARD_CLAIMS_UNTIL = 1666872000; // Thursday 27.10.22 12:00 GMT
const TOKEN_BUYER = "0x2979aC1a340470887f42F0cbDD2642599D15De81";
const VERIFIER = "0x3346cc4b6F44349EAC447b1C8392b2a472a20F27";

const SUBSCRIPTION_SERVICE = "0xBbC3Df0Af62b4a469DD44c1bc4e8804268dB1ea3";

const START_BLOCK = 21800000;
const END_BLOCK = 23500000;

// Params for BNB chain
const VRF_COORDINATOR_BNB_CHAIN = "0xc587d9053cd1118f25F645F9E08BB98c9712A4EE";
const SUBSCRIPTION_ID = "";
// 200 gwei keyhash
const KEY_HASH = "0x114f3da0a805b6a67d6e9cd2ec746f7028f1b7376365af575cfea3550dd1aa04";
const CALLBACK_GAS_LIMIT = BigNumber.from(150000);
const REQUEST_CONFIRMATION = BigNumber.from(3);
const NUM_WORDS = BigNumber.from(1);


async function main() {

    const FARMING = await ethers.getContractFactory("PureFiFarming2");
    const PROFIT_DISTRIBUTOR = await ethers.getContractFactory("ProfitDistributor");

    const PPROXY_ADMIN = await ethers.getContractFactory("PProxyAdmin");
    const PPROXY = await ethers.getContractFactory("PPRoxy");

    // deploy proxyAdmin 
    const proxyAdmin = await PPROXY_ADMIN.deploy();
    await proxyAdmin.deployed();
    
    console.log("Proxy admin address : ", proxyAdmin.address);

    // deploy farming master copy
    const farmingMasterCopy = await FARMING.deploy();
    await farmingMasterCopy.deployed();

    console.log("Farming Master copy address : ", farmingMasterCopy.address);
    let proxyAddress : string;
    {
        // deploy farming
        const farming = await PPROXY.deploy(
            farmingMasterCopy.address,
            proxyAdmin.address,
            ethers.utils.toUtf8Bytes("0x")
        );
        await farming.deployed();
        proxyAddress = farming.address;
        console.log("Farming address : ", farming.address);

    }
    const farming = await ethers.getContractAt("PureFiFarming2", proxyAddress);

    // initialize farming;
    await farming.initialize(
        ADMIN,
        TOKEN,
        TOKENS_PER_BLOCK,
        NO_REWARD_CLAIMS_UNTIL,
        TOKEN_BUYER,
        VERIFIER
    );
    console.log("Farming version : ", await farming.version());

    // deploy ProfitDistributor master copy

    const distributorMasterCopy = await PROFIT_DISTRIBUTOR.deploy();
    await distributorMasterCopy.deployed();

    console.log("Master copy address :", distributorMasterCopy.address);
    let distributorProxyAddress : string;
    {
        // deploy profitDistributor
        const distributor = await PPROXY.deploy(
            distributorMasterCopy.address,
            proxyAdmin.address,
            "0x"
        );
        await distributor.deployed();
        
        distributorProxyAddress = distributor.address;
        console.log("ProfitDistributor address :", distributorProxyAddress);
    }
    const distributorContract = await ethers.getContractAt("ProfitDistributor", distributorProxyAddress);

    // initialize ProfitDistributor

    await distributorContract.initialize(
        VRF_COORDINATOR_BNB_CHAIN,
        SUBSCRIPTION_ID,
        KEY_HASH,
        CALLBACK_GAS_LIMIT,
        REQUEST_CONFIRMATION,
        NUM_WORDS,
        farming.address,
        TOKEN,
        SUBSCRIPTION_SERVICE
    );
    
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});