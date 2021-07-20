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


contract('PureFiToken', (accounts) => {
 
    let admin   = accounts[0];
    const decimals = toBN(10).pow(toBN(18));
  
    console.log("Test: Admin: "+admin);

    let pureFiToken;
    let paymentPlan;
    // const startDate = 1627383600; // Jul 27 11:00 UTC
    const startDate = Math.round((new Date().getTime())/1000)+10;


    before(async () => {
        await PureFiToken.deployed().then(instance => pureFiToken = instance);
        console.log("startDate=",startDate);
        await PureFiFixedDatePaymentPlan.new().then(instance => paymentPlan = instance);
        await paymentPlan.initialize.sendTransaction(pureFiToken.address);

        
    });

    it('PureFi Token', async () => {

        let balance = await pureFiToken.balanceOf.call(admin);
        console.log("balance",balance.toString());
        expect(balance).to.be.eq.BN(toBN(100000000).mul(decimals));
  
    });

    it('add payment plan', async () => {

        let tgePercent = 33;
        let cliff = 1; //month
        let payout = 33.5;
        let payoutTimes = 2; //month

        const monthPeriod = 60*60*24*30; //30 days
        let unlockDates = [toBN(0)];
        let unlockPercents = [toBN(Math.round(tgePercent*100))];
        for( let i =0;i<payoutTimes;i++){
            unlockDates.push(toBN((cliff+i+1)*monthPeriod));
            unlockPercents.push(toBN(Math.round(payout*100)));
        }
        console.log("Adding payment plan:");
        for( let i =0;i<unlockDates.length;i++){
            console.log(i, ": ",unlockDates[i].toString()," - ",unlockPercents[i].toString());
        }

        let addPlanRes = await paymentPlan.addPaymentPlan.sendTransaction(unlockDates,unlockPercents);
        printEvents(addPlanRes, "Add payment plan");
  
    });

    it('add Vested Tokens', async () => {
        await pureFiToken.transfer.sendTransaction(paymentPlan.address,toBN(100000).mul(decimals));
        // vestTokens(uint8 _paymentPlan, uint64 _startDate, uint256 _amount, address _beneficiary)
        let totalVested = toBN(100).mul(decimals);
        let addVest = await paymentPlan.vestTokens.sendTransaction(toBN(0),startDate,totalVested,accounts[0]);
        printEvents(addVest, "addVest");
    
        //before start
        {
            let withdrawable = await paymentPlan.withdrawableAmount.call(accounts[0]);
            let nextUnlockDate = withdrawable[0].toNumber();
            let availableAmount = withdrawable[1];
            console.log(nextUnlockDate," ", availableAmount.toString());
            expect(availableAmount).to.be.eq.BN(toBN(0));

            await expectRevert(
                paymentPlan.withdraw(totalVested, {from: accounts[0]}),
                'revert'
            );
        }
        //just after start (TGE payment)
        await time.increase(time.duration.days(1));
        {
            let withdrawable = await paymentPlan.withdrawableAmount.call(accounts[0]);
            let nextUnlockDate = withdrawable[0].toNumber();
            let availableAmount = withdrawable[1];
            console.log(nextUnlockDate," ", availableAmount.toString());
            expect(availableAmount).to.be.eq.BN(toBN('33000000000000000000'));
            //attempt withdraw full amount
            await expectRevert(
                paymentPlan.withdraw(totalVested, {from: accounts[0]}),
                'revert'
            );
            
            {
                let balanceBefore = await pureFiToken.balanceOf(accounts[0]);
                await paymentPlan.withdraw(availableAmount, {from: accounts[0]})
                let balanceAfter = await pureFiToken.balanceOf(accounts[0]);
                expect(balanceAfter.sub(balanceBefore)).to.be.eq.BN(availableAmount);
            }
        }


        //1 month (cliff, no payment)
        await time.increase(time.duration.days(30));
        {
            let withdrawable = await paymentPlan.withdrawableAmount.call(accounts[0]);
            let nextUnlockDate = withdrawable[0].toNumber();
            let availableAmount = withdrawable[1];
            console.log(nextUnlockDate," ", availableAmount.toString());
            expect(availableAmount).to.be.eq.BN(toBN('0'));
        }
        //2 month (1st payout)
        await time.increase(time.duration.days(30));
        {
            let withdrawable = await paymentPlan.withdrawableAmount.call(accounts[0]);
            let nextUnlockDate = withdrawable[0].toNumber();
            let availableAmount = withdrawable[1];
            console.log(nextUnlockDate," ", availableAmount.toString());
            expect(availableAmount).to.be.eq.BN(toBN('33500000000000000000'));

            await expectRevert(
                paymentPlan.withdraw(totalVested, {from: accounts[0]}),
                'revert'
            );
            
            {
                let balanceBefore = await pureFiToken.balanceOf(accounts[0]);
                await paymentPlan.withdraw(availableAmount, {from: accounts[0]})
                let balanceAfter = await pureFiToken.balanceOf(accounts[0]);
                expect(balanceAfter.sub(balanceBefore)).to.be.eq.BN(availableAmount);
            }
        }
        //3 month (2nd payment - full amount)
        await time.increase(time.duration.days(30));
        {
            let withdrawable = await paymentPlan.withdrawableAmount.call(accounts[0]);
            let nextUnlockDate = withdrawable[0].toNumber();
            let availableAmount = withdrawable[1];
            console.log(nextUnlockDate," ", availableAmount.toString());
            expect(availableAmount).to.be.eq.BN(toBN('33500000000000000000'));

            await expectRevert(
                paymentPlan.withdraw(totalVested, {from: accounts[0]}),
                'revert'
            );
            
            {
                let balanceBefore = await pureFiToken.balanceOf(accounts[0]);
                await paymentPlan.withdraw(availableAmount, {from: accounts[0]})
                let balanceAfter = await pureFiToken.balanceOf(accounts[0]);
                expect(balanceAfter.sub(balanceBefore)).to.be.eq.BN(availableAmount);
            }
        }

        {
            let withdrawable = await paymentPlan.withdrawableAmount.call(accounts[0]);
            let nextUnlockDate = withdrawable[0].toNumber();
            let availableAmount = withdrawable[1];
            console.log(nextUnlockDate," ", availableAmount.toString());
            expect(availableAmount).to.be.eq.BN(toBN('0'));
        }


  
    });


    
   
});
