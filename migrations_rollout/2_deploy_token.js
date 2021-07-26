const PureFiToken = artifacts.require('PureFiToken');
const PureFiFixedDatePaymentPlan = artifacts.require('PureFiFixedDatePaymentPlan');
const PureFiLinearPaymentPlan = artifacts.require('PureFiLinearPaymentPlan');
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

    let pureFiToken;

    if(network.startsWith('bsc')){
        pureFiToken = await PureFiToken.at('');
        console.log("Using PureFi token", pureFiToken.address);
    }else{
        let swapAgentAddress = '';
        if(swapAgentAddress.length==0){
            throw new Error("No swap agent address defined");
        }
        
        let swapFee = toBN('0');
        if(swapFee.toString() === '0'){
            throw new Error("No swap fee defined");
        }

        await deployer.deploy(PureFiToken, admin)
        .then(function(){
            console.log("PureFiToken instance: ", PureFiToken.address);
            return PureFiToken.at(PureFiToken.address);
        }).then(function (instance){
            pureFiToken = instance; 
        });

        let swapAgent = await IETHBSCBridge.at(swapAgentAddress);
        let registerTx = await swapAgent.registerSwapPairToBSC(pureFiToken.address);
        console.log("*********************** REGISTER ***************************")
        console.log("Register TX: ",registerTx.tx.toString());
        console.log("UFI Token address: ",pureFiToken.address);
        console.log("*********************** REGISTER ***************************")
        printEvents(registerTx,"Register");

        let swapAmount = toBN(10000000).mul(decimals);
        await pureFiToken.approve.sendTransaction(swapAgent.address,swapAmount);
        let swapTx = await swapAgent.swapETH2BSC(pureFiToken.address, swapAmount, {from:admin, value:swapFee});
        console.log("*********************** SWAP ***************************")
        console.log("Swap TX: ", swapTx.tx.toString());
        console.log("toAddress: ", admin);
        console.log("amount: ", swapAmount.toString());
        console.log("*********************** SWAP ***************************")
        printEvents(swapTx,"Swap");

    }
    
};