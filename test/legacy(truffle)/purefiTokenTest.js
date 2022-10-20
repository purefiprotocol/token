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

    it('Check bot protection', async () => {
        let botAddress = accounts[1];
        let botWhitelistedAddress = accounts[2];
        let someBalance = toBN(10).mul(decimals);
        await pureFiToken.transfer.sendTransaction(botAddress, someBalance, {from:accounts[0]});
        await pureFiToken.transfer.sendTransaction(botWhitelistedAddress, someBalance, {from:accounts[0]});
        //enable bot protection for 10 blocks and 15 sec
        await botProtection.setBotLaunchpad.sendTransaction(accounts[0]);
        await pureFiToken.setBotProtector.sendTransaction(botProtection.address);
        await botProtection.prepareBotProtection.sendTransaction(toBN(10),toBN(15));
        //whitelist bot address
        await botProtection.setBotWhitelist.sendTransaction(botWhitelistedAddress,true);
        //successful transaction from whitelisted address
        {
            let balanceBefore = await pureFiToken.balanceOf(botWhitelistedAddress);
            await pureFiToken.transfer(accounts[0],someBalance, {from: botWhitelistedAddress})
            let balanceAfter = await pureFiToken.balanceOf(botWhitelistedAddress);
            expect(balanceBefore.sub(balanceAfter)).to.be.eq.BN(someBalance);
        }
        //not whitelisted addresses transactions are reverted
        {
            let balanceBefore = await pureFiToken.balanceOf(botAddress);
            await expectRevert(
                pureFiToken.transfer(accounts[0], someBalance, {from: botAddress}),
                'revert'
            );
            let balanceAfter = await pureFiToken.balanceOf(botAddress);
            expect(balanceAfter).to.be.eq.BN(balanceBefore);
        }
        //expire protection
        await time.increase(time.duration.seconds(30));
        let currentBlock = await time.latestBlock();
        for(let i=0;i<10;i++){
            await time.advanceBlock();
        }
        let shifedBlock = await time.latestBlock();
        console.log("Shifting block: ",currentBlock.toString()," => ",shifedBlock.toString());
        //check bot transaction is successful after protection expired
        {
            let balanceBefore = await pureFiToken.balanceOf(botAddress);
            await pureFiToken.transfer(accounts[0],someBalance, {from: botAddress})
            let balanceAfter = await pureFiToken.balanceOf(botAddress);
            expect(balanceBefore.sub(balanceAfter)).to.be.eq.BN(someBalance);
        }

    });

    it('add Fixed Date payment plan', async () => {

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

        let addPlanRes = await paymentPlanFD.addPaymentPlan.sendTransaction(unlockDates,unlockPercents);
        printEvents(addPlanRes, "Add payment plan");
  
    });

    it('add Linear payment plan', async () => {

        let tgePercent = 30;
        let cliff = 1; //month
        let payout = 10;
        let payoutTimes = 7; //daily

        let percentMult = (await paymentPlanLinear.PERCENT_100.call()).div(toBN(100)).toNumber();
        let initialPayoutPercent = tgePercent * percentMult;
        console.log("percentMult",percentMult);
        let cliffParam = cliff*30*24*60*60; //30 days month
        let period = 24*60*60; //daily payout
        let payoutPercent = percentMult*payout;

        //uint64 _cliff, uint64 _period, uint64 _initialPayoutPercent, uint64 _periodPayoutPercent
        console.log("Params: ",cliffParam," ",period," ", initialPayoutPercent," ",payoutPercent);
        let addPlanRes = await paymentPlanLinear.addPaymentPlan.sendTransaction(cliffParam, period, initialPayoutPercent, payoutPercent);
        printEvents(addPlanRes, "Add payment plan");

        let paymentPlanData = await paymentPlanLinear.paymentPlanData.call(0);
        expect(paymentPlanData[0]).to.be.eq.BN(toBN(cliffParam));
        expect(paymentPlanData[1]).to.be.eq.BN(toBN(period));
        expect(paymentPlanData[2]).to.be.eq.BN(toBN(initialPayoutPercent));
        expect(paymentPlanData[3]).to.be.eq.BN(toBN(payoutPercent));
  
    });

    it('test Fixed Date payment plan', async () => {
        let vestingStartTime = await time.latest();
        vestingStartTime = vestingStartTime.add(toBN(30));//sec
        console.log("time:", (await time.latest()).toString());
        console.log("vtime:",vestingStartTime.toString());

        await pureFiToken.transfer.sendTransaction(paymentPlanFD.address,toBN(100000).mul(decimals));
        // vestTokens(uint8 _paymentPlan, uint64 _startDate, uint256 _amount, address _beneficiary)
        let totalVested = toBN(100).mul(decimals);
        let addVest = await paymentPlanFD.vestTokens.sendTransaction(toBN(0),vestingStartTime,totalVested,accounts[0]);
        printEvents(addVest, "addVest");
    
        //before start
        {
            let withdrawable = await paymentPlanFD.withdrawableAmount.call(accounts[0]);
            let nextUnlockDate = withdrawable[0].toNumber();
            let availableAmount = withdrawable[1];
            console.log(nextUnlockDate," ", availableAmount.toString());
            expect(availableAmount).to.be.eq.BN(toBN(0));

            await expectRevert(
                paymentPlanFD.withdraw(totalVested, {from: accounts[0]}),
                'revert'
            );
        }
        //just after start (TGE payment)
        await time.increase(time.duration.days(1));
        {
            let withdrawable = await paymentPlanFD.withdrawableAmount.call(accounts[0]);
            let nextUnlockDate = withdrawable[0].toNumber();
            let availableAmount = withdrawable[1];
            console.log(nextUnlockDate," ", availableAmount.toString());
            expect(availableAmount).to.be.eq.BN(toBN('33000000000000000000'));
            //attempt withdraw full amount
            await expectRevert(
                paymentPlanFD.withdraw(totalVested, {from: accounts[0]}),
                'revert'
            );
            
            {
                let balanceBefore = await pureFiToken.balanceOf(accounts[0]);
                await paymentPlanFD.withdraw(availableAmount, {from: accounts[0]})
                let balanceAfter = await pureFiToken.balanceOf(accounts[0]);
                expect(balanceAfter.sub(balanceBefore)).to.be.eq.BN(availableAmount);
            }
        }


        //1 month (cliff, no payment)
        await time.increase(time.duration.days(30));
        {
            let withdrawable = await paymentPlanFD.withdrawableAmount.call(accounts[0]);
            let nextUnlockDate = withdrawable[0].toNumber();
            let availableAmount = withdrawable[1];
            console.log(nextUnlockDate," ", availableAmount.toString());
            expect(availableAmount).to.be.eq.BN(toBN('0'));
        }
        //2 month (1st payout)
        await time.increase(time.duration.days(30));
        {
            let withdrawable = await paymentPlanFD.withdrawableAmount.call(accounts[0]);
            let nextUnlockDate = withdrawable[0].toNumber();
            let availableAmount = withdrawable[1];
            console.log(nextUnlockDate," ", availableAmount.toString());
            expect(availableAmount).to.be.eq.BN(toBN('33500000000000000000'));

            await expectRevert(
                paymentPlanFD.withdraw(totalVested, {from: accounts[0]}),
                'revert'
            );
            
            {
                let balanceBefore = await pureFiToken.balanceOf(accounts[0]);
                await paymentPlanFD.withdraw(availableAmount, {from: accounts[0]})
                let balanceAfter = await pureFiToken.balanceOf(accounts[0]);
                expect(balanceAfter.sub(balanceBefore)).to.be.eq.BN(availableAmount);
            }
        }
        //3 month (2nd payment - full amount)
        await time.increase(time.duration.days(30));
        {
            let withdrawable = await paymentPlanFD.withdrawableAmount.call(accounts[0]);
            let nextUnlockDate = withdrawable[0].toNumber();
            let availableAmount = withdrawable[1];
            console.log(nextUnlockDate," ", availableAmount.toString());
            expect(availableAmount).to.be.eq.BN(toBN('33500000000000000000'));

            await expectRevert(
                paymentPlanFD.withdraw(totalVested, {from: accounts[0]}),
                'revert'
            );
            
            {
                let balanceBefore = await pureFiToken.balanceOf(accounts[0]);
                await paymentPlanFD.withdraw(availableAmount, {from: accounts[0]})
                let balanceAfter = await pureFiToken.balanceOf(accounts[0]);
                expect(balanceAfter.sub(balanceBefore)).to.be.eq.BN(availableAmount);
            }
        }

        {
            let withdrawable = await paymentPlanFD.withdrawableAmount.call(accounts[0]);
            let nextUnlockDate = withdrawable[0].toNumber();
            let availableAmount = withdrawable[1];
            console.log(nextUnlockDate," ", availableAmount.toString());
            expect(availableAmount).to.be.eq.BN(toBN('0'));
        }


  
    });

    it('test Linear payment plan', async () => {

        let vestingStartTime = await time.latest();
        vestingStartTime = vestingStartTime.add(toBN(30));//sec
        console.log("time:", (await time.latest()).toString());
        console.log("vtime:",vestingStartTime.toString());
        // await time.advanceBlock();
        await pureFiToken.transfer.sendTransaction(paymentPlanLinear.address,toBN(100000).mul(decimals));
        // vestTokens(uint8 _paymentPlan, uint64 _startDate, uint256 _amount, address _beneficiary)
        let totalVested = toBN(100).mul(decimals);
        let addVest = await paymentPlanLinear.vestTokens.sendTransaction(toBN(0),vestingStartTime,totalVested,accounts[0]);
        printEvents(addVest, "addVest");
    
        //before start
        {
            console.log("time:", (await time.latest()).toString());
            let withdrawable = await paymentPlanLinear.withdrawableAmount.call(accounts[0]);
            let nextUnlockDate = withdrawable[0].toNumber();
            let availableAmount = withdrawable[1];
            console.log(nextUnlockDate," ", availableAmount.toString());
            expect(availableAmount).to.be.eq.BN(toBN(0));

            await expectRevert(
                paymentPlanLinear.withdraw(totalVested, {from: accounts[0]}),
                'revert'
            );
        }
        //just after start (TGE payment)
        await time.increase(time.duration.days(1));
        {
            console.log("time:", (await time.latest()).toString());
            let withdrawable = await paymentPlanLinear.withdrawableAmount.call(accounts[0]);
            let nextUnlockDate = withdrawable[0].toNumber();
            let availableAmount = withdrawable[1];
            console.log(nextUnlockDate," ", availableAmount.toString());
            expect(availableAmount).to.be.eq.BN(toBN('30000000000000000000'));
            //attempt withdraw full amount
            await expectRevert(
                paymentPlanLinear.withdraw(totalVested, {from: accounts[0]}),
                'revert'
            );
            
            {
                let balanceBefore = await pureFiToken.balanceOf(accounts[0]);
                await paymentPlanLinear.withdraw(availableAmount, {from: accounts[0]})
                let balanceAfter = await pureFiToken.balanceOf(accounts[0]);
                expect(balanceAfter.sub(balanceBefore)).to.be.eq.BN(availableAmount);
            }
        }


        //1 month (cliff, no payment)
        await time.increase(time.duration.days(30));
        {
            console.log("time:", (await time.latest()).toString());
            let withdrawable = await paymentPlanLinear.withdrawableAmount.call(accounts[0]);
            let nextUnlockDate = withdrawable[0].toNumber();
            let availableAmount = withdrawable[1];
            console.log(nextUnlockDate," ", availableAmount.toString());
            expect(availableAmount).to.be.eq.BN(toBN('0'));
        }


        //loop daily payments
        var daysPaid = 0;
        while(daysPaid<10){
            await time.increase(time.duration.days(1));
            console.log("time:", (await time.latest()).toString());
            let withdrawable = await paymentPlanLinear.withdrawableAmount.call(accounts[0]);
            let nextUnlockDate = withdrawable[0].toNumber();
            let availableAmount = withdrawable[1];
            console.log("day",daysPaid," nextUnlockDate=", nextUnlockDate," available=", availableAmount.toString());
            if(availableAmount.eq(toBN(0))){
                expect(withdrawable[0]).to.be.eq.BN(toBN('0'));
                break;
            }
            expect(availableAmount).to.be.eq.BN(toBN('10000000000000000000'));

            await expectRevert(
                paymentPlanLinear.withdraw(totalVested, {from: accounts[0]}),
                'revert'
            );
            
            {
                let balanceBefore = await pureFiToken.balanceOf(accounts[0]);
                await paymentPlanLinear.withdraw(availableAmount, {from: accounts[0]})
                let balanceAfter = await pureFiToken.balanceOf(accounts[0]);
                expect(balanceAfter.sub(balanceBefore)).to.be.eq.BN(availableAmount);
            }
            daysPaid++;
        }

        assert.equal(daysPaid,7,"Incorrect days paid");


        {
            let withdrawable = await paymentPlanFD.withdrawableAmount.call(accounts[0]);
            let nextUnlockDate = withdrawable[0].toNumber();
            let availableAmount = withdrawable[1];
            console.log(nextUnlockDate," ", availableAmount.toString());
            expect(availableAmount).to.be.eq.BN(toBN('0'));
        }


  
    });


    
   
});
