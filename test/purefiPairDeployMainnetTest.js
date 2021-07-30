const { time, expectRevert } = require('@openzeppelin/test-helpers');
const bigDecimal = require('js-big-decimal');
const web3 = require("web3");
const BN = web3.utils.BN;
const chai = require('chai');
const expect = chai.expect;
const assert = chai.assert;
chai.use(require('bn-chai')(BN));
chai.use(require('chai-match'));

const PureFiToken = artifacts.require('PureFiToken');
const PureFiFixedDatePaymentPlan = artifacts.require('PureFiFixedDatePaymentPlan');
const PureFiLinearPaymentPlan = artifacts.require('PureFiLinearPaymentPlan');
const PureFiBotProtection = artifacts.require('PureFiBotProtection');
const PureFiUniswapReg = artifacts.require('PureFiUniswapReg');

function toBN(number) {
    return web3.utils.toBN(number);
}

function printEvents(txResult, strdata){
    console.log(strdata," events:",txResult.logs.length);
    for(var i=0;i<txResult.logs.length;i++){
        let argsLength = Object.keys(txResult.logs[i].args).length;
        console.log("Event ",txResult.logs[i].event, "  length:",argsLength);
        for(var j=0;j<argsLength;j++){
            if(!(typeof txResult.logs[i].args[j] === 'undefined') && txResult.logs[i].args[j].toString().length>0)
                console.log(">",i,">",j," ",txResult.logs[i].args[j].toString());
        }
    }

}


contract('PureFi Uniswwap pair deploy', (accounts) => {
 
    let admin   = accounts[0];
    const decimals = toBN(10).pow(toBN(18));
  
    console.log("Test: Admin: "+admin);

    let pureFiToken;
    let botProtection;
    let paymentPlanFD;
    let paymentPlanLinear;
    // const startDate = 1627383600; // Jul 27 11:00 UTC
    const startDate = Math.round((new Date().getTime())/1000)+10;


    before(async () => {
        await PureFiToken.deployed().then(instance => pureFiToken = instance);
        await PureFiBotProtection.deployed().then(instance => botProtection = instance);
        
        console.log("startDate=",startDate);
        await PureFiFixedDatePaymentPlan.new().then(instance => paymentPlanFD = instance);
        await paymentPlanFD.initialize.sendTransaction(pureFiToken.address);

        await PureFiLinearPaymentPlan.new().then(instance => paymentPlanLinear = instance);
        await paymentPlanLinear.initialize.sendTransaction(pureFiToken.address);

        
    });

    it('PureFi Token', async () => {
        let balance = await pureFiToken.balanceOf.call(admin);
        console.log("balance",balance.toString());
        expect(balance).to.be.eq.BN(toBN(100000000).mul(decimals));
  
    });

    it('check autodeploy uniswap pair', async () =>{
        let regContract;
        await PureFiUniswapReg.new().then(instance => regContract = instance);

        let router = await regContract.routerAddress();
        console.log("pureFiToken.address",pureFiToken.address);
        let pairAddress = await regContract.getPairAddress(pureFiToken.address);
        console.log("Pair Address", pairAddress);

        let whitelist = [router, admin , pairAddress, regContract.address];
        
        //whitelist 
        await botProtection.setBotLaunchpad(regContract.address, {from:admin});
        await botProtection.setBotWhitelists(whitelist, {from:admin});
        
        let firewallBlockLength = toBN(10);
        let firewallTimeLength = toBN(300);
        let amountUFI = toBN(1000).mul(decimals);
        let amountETH = toBN('21308000000000000')//$45

        await pureFiToken.transfer(regContract.address, amountUFI, {from:admin});
        let regTx = await regContract.registerPair(pureFiToken.address, botProtection.address, amountUFI, amountETH, firewallBlockLength, firewallTimeLength, {from:admin, value: amountETH});
        printEvents(regTx);

        //expire protection
        await time.increase(time.duration.seconds(310));
        let currentBlock = await time.latestBlock();
        for(let i=0;i<11;i++){
            await time.advanceBlock();
        }
        let shifedBlock = await time.latestBlock();
        console.log("Shifting block: ",currentBlock.toString()," => ",shifedBlock.toString());

        await botProtection.finalizeBotProtection.sendTransaction({from:admin});
    });

    
   
});
