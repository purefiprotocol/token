const PureFiToken = artifacts.require('PureFiToken');
const PureFiFixedDatePaymentPlan = artifacts.require('PureFiFixedDatePaymentPlan');
const PureFiLinearPaymentPlan = artifacts.require('PureFiLinearPaymentPlan');
const PureFiFarming = artifacts.require('PureFiFarming');
const PProxyAdmin = artifacts.require('PProxyAdmin');
const PProxy = artifacts.require('PProxy');
const PureFiBotProtection = artifacts.require('PureFiBotProtection');
const web3 = require("web3");
const BN = web3.utils.BN;
const { time } = require('@openzeppelin/test-helpers');

function toBN(number) {
    return web3.utils.toBN(number);
}

module.exports = async function (deployer, network, accounts) {
    
    let admin = accounts[0];
    let trustedForwarder;

    if(network == 'rinkeby' || network == 'rinkeby-fork'){
        trustedForwarder = '0x83A54884bE4657706785D7309cf46B58FE5f6e8a';
    } else if(network == 'mainnet' || network == 'mainnet-fork'){
        trustedForwarder = '0xAa3E82b4c4093b4bA13Cb5714382C99ADBf750cA';
    } else if(network == 'kovan' || network == 'kovan-fork'){
        trustedForwarder = '0x7eEae829DF28F9Ce522274D5771A6Be91d00E5ED';
    }else if(network == 'ropsten' || network == 'ropsten-fork'){
        trustedForwarder = '0xeB230bF62267E94e657b5cbE74bdcea78EB3a5AB';
    }else if(network == 'test'){
        trustedForwarder = '0xAa3E82b4c4093b4bA13Cb5714382C99ADBf750cA';
    }

    console.log("Deploy: Admin: "+admin);
    console.log("Deploy: forwarder: "+trustedForwarder);

    
    let pureFiToken;
    await deployer.deploy(PureFiToken, admin, trustedForwarder)
    .then(function(){
        console.log("PureFiToken instance: ", PureFiToken.address);
        return PureFiToken.at(PureFiToken.address);
    }).then(function (instance){
        pureFiToken = instance; 
    });

    let botProtector;
    await deployer.deploy(PureFiBotProtection, admin, pureFiToken.address)
    .then(function(){
        console.log("PureFiBotProtection instance: ", PureFiBotProtection.address);
        return PureFiBotProtection.at(PureFiBotProtection.address);
    }).then(function (instance){
        botProtector = instance; 
    });

    //deploy master admin
    let proxyAdmin;
    await PProxyAdmin.new().then(instance => proxyAdmin = instance);
    console.log("Proxy Admin: ",proxyAdmin.address);

    //deploy farming
    let masterFarmingCopy;
    await PureFiFarming.new().then(instance => masterFarmingCopy = instance);

    let farming;
    await PProxy.new(masterFarmingCopy.address,proxyAdmin.address,web3.utils.hexToBytes('0x')).
        then(function(instance){
            return PureFiFarming.at(instance.address);
        }).then(instance => farming = instance);
    console.log("Farming instance: ", farming.address);
    console.log("Using Farming version",(await farming.version.call()).toString());
    //deploy payment plans
    let masterPPLinear;
    await PureFiLinearPaymentPlan.new().then(instance => masterPPLinear = instance);
    let masterPPFixed;
    await PureFiFixedDatePaymentPlan.new().then(instance => masterPPFixed = instance);

    let paymentPlanLinear;
    await PProxy.new(masterPPLinear.address,proxyAdmin.address,web3.utils.hexToBytes('0x')).
        then(function(instance){
            return PureFiLinearPaymentPlan.at(instance.address);
        }).then(instance => paymentPlanLinear = instance);
    await paymentPlanLinear.initialize.sendTransaction(pureFiToken.address, {from: admin});
    console.log("PaymentPlanLinear instance: ", paymentPlanLinear.address);

    let paymentPlanFixed;
    await PProxy.new(masterPPFixed.address,proxyAdmin.address,web3.utils.hexToBytes('0x')).
        then(function(instance){
            return PureFiFixedDatePaymentPlan.at(instance.address);
        }).then(instance => paymentPlanFixed = instance);
    await paymentPlanFixed.initialize.sendTransaction(pureFiToken.address, {from: admin});
    console.log("PaymentPlanFixed instance: ", paymentPlanFixed.address);


    if(network == "rinkeby" || network == "rinkeby-fork" ||
        network == "bsctest" || network == "bsctest-fork" ||
        network == "test"){
            //configure farming
            let decimals = toBN(10).pow(await pureFiToken.decimals.call());
            totalRewardPerBlock = toBN(100).mul(decimals);
            let startDate = Math.round((new Date().getTime())/1000)+10;
            await farming.initialize.sendTransaction(accounts[0],pureFiToken.address,totalRewardPerBlock,toBN(startDate), {from: admin});
            //send tokens to farming contract
            if(network != 'test'){
                await pureFiToken.transfer(farming.address, toBN(100000).mul(decimals));
            }
            //add pool
            let farmingStartBlock;
            let farmingEndBlock;
            if(network == 'test'){
                let block= await time.latestBlock();
                console.log("block number: ", block.toString());
                farmingStartBlock = block.add(toBN(10));
                farmingEndBlock = block.add(toBN(100000));
            } else{
                let block = await web3.eth.getBlock("latest")
                console.log("block number: ", block.number.toString());
                // let block= await time.latestBlock();
                farmingStartBlock = block.number.add(toBN(10));
                farmingEndBlock = block.number.add(toBN(100000));
            }

            await farming.addPool.sendTransaction(toBN(100), pureFiToken.address, farmingStartBlock, farmingEndBlock, true);

            let data = await farming.getPool.call(toBN(0));
            let index=0;
            console.log("share: ", data[index++].toString());
            console.log("token: ", data[index++].toString());
            console.log("startBlock: ", data[index++].toString());
            console.log("endBlock: ", data[index++].toString());
            console.log("lastRewardBlock: ", data[index++].toString());
            console.log("acctPerShare: ", data[index++].toString());
            console.log("totalDeposited: ", data[index++].toString());
        }
    

   
    

  

};