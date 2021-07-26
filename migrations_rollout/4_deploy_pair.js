const PureFiToken = artifacts.require('PureFiToken');
const PureFiPancakeReg = artifacts.require('PureFiPancakeReg');
const PureFiUniswapReg = artifacts.require('PureFiUniswapReg');
const PureFiFarming = artifacts.require('PureFiFarming');
const PProxyAdmin = artifacts.require('PProxyAdmin');
const PProxy = artifacts.require('PProxy');
const PureFiBotProtection = artifacts.require('PureFiBotProtection');
const IETHBSCBridge = artifacts.require('IETHBSCBridge');
const web3 = require("web3");
const BN = web3.utils.BN;
const { time } = require('@openzeppelin/test-helpers');

function toBN(number) {
    return web3.utils.toBN(number);
}

function printEvents(txResult, strdata) {
    console.log(strdata, " events:", txResult.logs.length);
    for (var i = 0; i < txResult.logs.length; i++) {
        let argsLength = Object.keys(txResult.logs[i].args).length;
        console.log("Event ", txResult.logs[i].event, "  length:", argsLength);
        for (var j = 0; j < argsLength; j++) {
            if (!(typeof txResult.logs[i].args[j] === 'undefined') && txResult.logs[i].args[j].toString().length > 0)
                console.log(">", i, ">", j, " ", txResult.logs[i].args[j].toString());
        }
    }
}

module.exports = async function (deployer, network, accounts) {
    
    let admin = accounts[0];

    console.log("Deploy: Admin: "+admin);

    let pureFiTokenAddress;
    let botProtectionAddress;

    if(network == 'rinkeby' || network == 'rinkeby-fork'){
        pureFiTokenAddress = '';
        botProtectionAddress = '';
    } else if(network == 'mainnet' || network == 'mainnet-fork'){
        pureFiTokenAddress = '';
        botProtectionAddress = '';
    } else if(network == 'kovan' || network == 'kovan-fork'){
        pureFiTokenAddress = '';
        botProtectionAddress = '';
    }else if(network == 'ropsten' || network == 'ropsten-fork'){
        pureFiTokenAddress = '';
        botProtectionAddress = '';
    }else if(network == 'test'){
        pureFiTokenAddress = '';
        botProtectionAddress = '';
    }else if(network == 'bsctest' || network == 'bsctest-fork'){
        pureFiTokenAddress = '';
        botProtectionAddress = '';
    }else if(network == 'bsc' || network == 'bsc-fork'){
        pureFiTokenAddress = '';
        botProtectionAddress = '';
    }

    if(pureFiTokenAddress.length==0){
        throw new Error("No token address defined");
    }
    if(botProtectionAddress.length==0){
        throw new Error("No token address defined");
    }

    let pureFiToken = await PureFiToken.at(pureFiTokenAddress);
    console.log("Using PureFi token", pureFiToken.address);
    let botProtection = await PureFiBotProtection.at(botProtectionAddress);


    let regContract;

    if(network.startsWith('bsc')){
        await deployer.deploy(PureFiPancakeReg)
        .then(function(){
            console.log("PureFiPancakeReg instance: ", PureFiPancakeReg.address);
            return PureFiPancakeReg.at(PureFiPancakeReg.address);
        }).then(function (instance){
            regContract = instance; 
        });

        let router = await regContract.routerAddress();
        console.log("pureFiToken.address",pureFiToken.address);
        let pairAddress = await regContract.getPairAddress(pureFiToken.address);
        console.log("Pair Address", pairAddress);

        let whitelist = [router, admin , pairAddress, regContract.address,
            '0x03F39b5355Ea172ba7e9198Fd9E7fB6977Fee842',
            '0xc81767c223C35A2cC6fd59dbE5D1Db1bEcbc3022',
            '0x2c8BA1f0B04d8EBE186451abDEAb0e486Dae3774',
            '0xF1dfB8e10e843Fa2022d1F6208dd7f6E66497986'];
        
        //whitelist 
        await botProtection.setBotLaunchpad(regContract.address, {from:admin});
        await botProtection.setBotWhitelists(whitelist, {from:admin});
        
        let firewallBlockLength = toBN(10);
        let firewallTimeLength = toBN(300);
        let amountUFI = toBN(1000).mul(decimals);
        let amountBNB = toBN('150352000000000000')//$45

        await pureFiToken.transfer(regContract.address, amountUFI, {from:admin});
        let regTx = await regContract.registerPair(pureFiToken.address, botProtection.address, amountUFI, firewallBlockLength, firewallTimeLength, {from:admin, value: amountBNB});
        printEvents(regTx);

    }else{
        await deployer.deploy(PureFiUniswapReg)
        .then(function(){
            console.log("PureFiUniswapReg instance: ", PureFiUniswapReg.address);
            return PureFiUniswapReg.at(PureFiUniswapReg.address);
        }).then(function (instance){
            regContract = instance; 
        });

        let router = await regContract.routerAddress();
        console.log("pureFiToken.address",pureFiToken.address);
        let pairAddress = await regContract.getPairAddress(pureFiToken.address);
        console.log("Pair Address", pairAddress);

        let whitelist = [router, admin , pairAddress, regContract.address,
            '0x03F39b5355Ea172ba7e9198Fd9E7fB6977Fee842',
            '0xc81767c223C35A2cC6fd59dbE5D1Db1bEcbc3022',
            '0x2c8BA1f0B04d8EBE186451abDEAb0e486Dae3774',
            '0xF1dfB8e10e843Fa2022d1F6208dd7f6E66497986'];
        
        //whitelist 
        await botProtection.setBotLaunchpad(regContract.address, {from:admin});
        await botProtection.setBotWhitelists(whitelist, {from:admin});
        
        let firewallBlockLength = toBN(10);
        let firewallTimeLength = toBN(300);
        let amountUFI = toBN(1000).mul(decimals);
        let amountETH = toBN('21308000000000000')//$45

        await pureFiToken.transfer(regContract.address, amountUFI, {from:admin});
        let regTx = await regContract.registerPair(pureFiToken.address, botProtection.address, amountUFI, firewallBlockLength, firewallTimeLength, {from:admin, value: amountETH});
        printEvents(regTx);

    }

    
    
};