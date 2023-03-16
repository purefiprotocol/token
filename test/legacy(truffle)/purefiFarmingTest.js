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
const PProxy = artifacts.require('PProxy');
const PProxyAdmin = artifacts.require('PProxyAdmin');
const PureFiFarming = artifacts.require('PureFiFarming');
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

async function advanceBlock(shift){
    let currentBlock = await time.latestBlock();
    for(let i=0;i<shift;i++){
        await time.advanceBlock();
    }
    let shifedBlock = await time.latestBlock();
    console.log("Shifting block: ",currentBlock.toString()," => ",shifedBlock.toString());
}


contract('PureFiFarming', (accounts) => {
 
    let admin   = accounts[0];
    const decimals = toBN(10).pow(toBN(18));
  
    console.log("Test: Admin: "+admin);

    let pureFiToken;
    let farming;
    let proxyAdmin;

    const startDate = Math.round((new Date().getTime())/1000)+10;

    let farmingStartBlock;
    let farmingEndBlock;
    let totalRewardPerBlock;
    
    // const startDate = 1627383600; // Jul 27 11:00 UTC
    // const startDate = Math.round((new Date().getTime())/1000)+10;


    before(async () => {
        await PureFiToken.deployed().then(instance => pureFiToken = instance);

        await PProxyAdmin.new().then(instance => proxyAdmin = instance);

        let masterFarmingCopy;
        await PureFiFarming.new().then(instance => masterFarmingCopy = instance);

        let proxyInstance;
        await PProxy.new(masterFarmingCopy.address,proxyAdmin.address,web3.utils.hexToBytes('0x')).then(instance => proxyInstance = instance);
        farming = await PureFiFarming.at(proxyInstance.address);

        console.log("Using Farming version",(await farming.version.call()).toString());

        totalRewardPerBlock = toBN(100).mul(decimals);

        await farming.initialize.sendTransaction(accounts[0],pureFiToken.address,totalRewardPerBlock,toBN(startDate));
        //send tokens to farming contract
        await pureFiToken.transfer(farming.address, toBN(100000).mul(decimals));

        let block= await time.latestBlock();
        farmingStartBlock = block.add(toBN(10));
        farmingEndBlock = block.add(toBN(210));
        
        
    });

    it('Farming add pool', async () => {
 
        await farming.addPool.sendTransaction(toBN(100),pureFiToken.address, farmingStartBlock, farmingEndBlock, toBN(0),toBN(100000).mul(decimals), true);
        
        let data = await farming.getPool.call(toBN(0));
        let index=0;
        console.log("share: ", data[index++].toString());
        console.log("token: ", data[index++].toString());
        console.log("startBlock: ", data[index++].toString());
        console.log("endBlock: ", data[index++].toString());
        console.log("lastRewardBlock: ", data[index++].toString());
        console.log("acctPerShare: ", data[index++].toString());
        console.log("totalDeposited: ", data[index++].toString());
    });

    it('Deposit/withdraw', async () => {

        let depositBalance = toBN(100).mul(decimals);
        await pureFiToken.approve.sendTransaction(farming.address, depositBalance, {from: accounts[0]});
        await farming.deposit.sendTransaction(toBN(0),depositBalance);

        {
            let data = await farming.getUserInfo.call(toBN(0),accounts[0]);
            expect(data[0]).to.be.eq.BN(depositBalance);
            expect(data[1]).to.be.eq.BN(toBN(0));
            expect(data[2]).to.be.eq.BN(toBN(0));
        }
        await farming.withdraw.sendTransaction(toBN(0),depositBalance);

        {
            let data = await farming.getUserInfo.call(toBN(0),accounts[0]);
            expect(data[0]).to.be.eq.BN(toBN(0));
            expect(data[1]).to.be.eq.BN(toBN(0));
            expect(data[2]).to.be.eq.BN(toBN(0));
        }
        
    });

    it('Farm', async () => {

        let depositBalance = toBN(100).mul(decimals);
        await pureFiToken.approve.sendTransaction(farming.address, depositBalance, {from: accounts[0]});
        let depoRes = await farming.deposit.sendTransaction(toBN(0),depositBalance);
        printEvents(depoRes,"DepoRes");

        {
            let data = await farming.getUserInfo.call(toBN(0),accounts[0]);
            expect(data[0]).to.be.eq.BN(depositBalance);
            expect(data[1]).to.be.eq.BN(toBN(0));
            expect(data[2]).to.be.eq.BN(toBN(0));
        }
        
        //shift some blocks
        await advanceBlock(3);

        {
            let data = await farming.getUserInfo.call(toBN(0),accounts[0]);
            let index=0;
            console.log("amount: ", data[index++].toString());
            console.log("totalRewardClaimed: ", data[index++].toString());
            console.log("withdrawableReward: ", data[index++].toString());
        }
        await advanceBlock(20);
        {
            let data = await farming.getUserInfo.call(toBN(0),accounts[0]);
            let index=0;
            console.log("amount: ", data[index++].toString());
            console.log("totalRewardClaimed: ", data[index++].toString());
            console.log("withdrawableReward: ", data[index++].toString());
        }

        await expectRevert(
                    farming.claimReward.sendTransaction(toBN(0)),
                        'revert'
                    );
        
        await time.increase(time.duration.days(1));            

        {
            let data = await farming.getUserInfo.call(toBN(0),accounts[0]);
            let index=0;
            console.log("amount: ", data[index++].toString());
            console.log("totalRewardClaimed: ", data[index++].toString());
            console.log("withdrawableReward: ", data[index++].toString());
        }

        let claimRes = await farming.claimReward.sendTransaction(toBN(0));
        printEvents(claimRes, "claimRes");
        {
            let data = await farming.getUserInfo.call(toBN(0),accounts[0]);
            let index=0;
            console.log("amount: ", data[index++].toString());
            console.log("totalRewardClaimed: ", data[index++].toString());
            console.log("withdrawableReward: ", data[index++].toString());
        }
        await advanceBlock(1);
        {
            let data = await farming.getUserInfo.call(toBN(0),accounts[0]);
            let index=0;
            console.log("amount: ", data[index++].toString());
            console.log("totalRewardClaimed: ", data[index++].toString());
            console.log("withdrawableReward: ", data[index++].toString());
        }
        // await farming.deposit.sendTransaction(toBN(0),depositBalance);
        let exitRes = await farming.exit.sendTransaction(toBN(0));
        printEvents(exitRes, "exitRes");
        {
            let data = await farming.getUserInfo.call(toBN(0),accounts[0]);
            let index=0;
            console.log("amount: ", data[index++].toString());
            console.log("totalRewardClaimed: ", data[index++].toString());
            console.log("withdrawableReward: ", data[index++].toString());
        }
        {
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


        // await farming.withdraw.sendTransaction(toBN(0),depositBalance);

        // {
        //     let data = await farming.getUserInfo.call(toBN(0),accounts[0]);
        //     expect(data[0]).to.be.eq.BN(toBN(0));
        //     expect(data[1]).to.be.eq.BN(toBN(0));
        // }
        
    });

    it('Claim & Stake test', async () => {

        let paymentPlanFD;
        await PureFiFixedDatePaymentPlan.new().then(instance => paymentPlanFD = instance);
        await paymentPlanFD.initialize.sendTransaction(pureFiToken.address);

        await paymentPlanFD.setFarmingContract.sendTransaction(farming.address,toBN(0));

        //add payment plan with 2 dates:
        let currentTime = await time.latest();
        await time.advanceBlock();
        let unlockDates = [toBN(0), currentTime.add(toBN(86400))];
        let unlockPercents = [toBN(50*100),toBN(50*100)];
        
        console.log("Adding payment plan:");
        for( let i =0;i<unlockDates.length;i++){
            console.log(i, ": ",unlockDates[i].toString()," - ",unlockPercents[i].toString());
        }

        let addPlanRes = await paymentPlanFD.addPaymentPlan.sendTransaction(unlockDates,unlockPercents);

        await pureFiToken.transfer.sendTransaction(paymentPlanFD.address,toBN(100000).mul(decimals));
        // vestTokens(uint8 _paymentPlan, uint64 _startDate, uint256 _amount, address _beneficiary)
        let totalVested = toBN(100).mul(decimals);
        let addVest = await paymentPlanFD.vestTokens.sendTransaction(toBN(0),currentTime.sub(toBN(86400)),totalVested,accounts[0]);
        printEvents(addVest, "addVest");

         //check available
         {
            let withdrawable = await paymentPlanFD.withdrawableAmount.call(accounts[0]);
            let nextUnlockDate = withdrawable[0].toNumber();
            let availableAmount = withdrawable[1];
            console.log(nextUnlockDate," ", availableAmount.toString());
            expect(availableAmount).to.be.eq.BN(toBN(50).mul(decimals));
            

            {
                let balanceBefore = await pureFiToken.balanceOf(accounts[0]);
                await paymentPlanFD.withdrawAndStake(availableAmount, {from: accounts[0]})
                let balanceAfter = await pureFiToken.balanceOf(accounts[0]);
                expect(balanceAfter).to.be.eq.BN(balanceBefore);

                let data = await farming.getUserInfo.call(toBN(0),accounts[0]);
                let index=0;
                console.log("amount: ", data[index++].toString());
                console.log("totalRewardClaimed: ", data[index++].toString());
                console.log("withdrawableReward: ", data[index++].toString());
                expect(data[0]).to.be.eq.BN(availableAmount);
            }
        }
        
    });

    it('Farming update pool', async () => {
        {
            console.log("******* Before ************");
            let data = await farming.getPool.call(toBN(0));
            let index=0;
            console.log("token: ", data[index++].toString());
            console.log("allocPoint: ", data[index++].toString());
            console.log("startBlock: ", data[index++].toString());
            console.log("endBlock: ", data[index++].toString());
            console.log("lastRewardBlock: ", data[index++].toString());
            console.log("acctPerShare: ", data[index++].toString());
            console.log("totalDeposited: ", data[index++].toString());
        }

        // await farming.updatePoolData.sendTransaction(toBN(0), toBN(100), farmingStartBlock, farmingEndBlock.add(toBN(1)), false);
        // await farming.setTokenPerBlock.sendTransaction(totalRewardPerBlock.mul(toBN(2)));

        {
            console.log("******* AFTER ************");
            let data = await farming.getPool.call(toBN(0));
            let index=0;
            console.log("token: ", data[index++].toString());
            console.log("allocPoint: ", data[index++].toString());
            console.log("startBlock: ", data[index++].toString());
            console.log("endBlock: ", data[index++].toString());
            console.log("lastRewardBlock: ", data[index++].toString());
            console.log("acctPerShare: ", data[index++].toString());
            console.log("totalDeposited: ", data[index++].toString());
        }
 
        
    });

    it('Farm after updated', async () => {
        //exit everything before 
        await farming.exit.sendTransaction(toBN(0));

        let depositBalance = toBN(100).mul(decimals);
        await pureFiToken.approve.sendTransaction(farming.address, depositBalance, {from: accounts[0]});
        let depoRes = await farming.deposit.sendTransaction(toBN(0),depositBalance);
        printEvents(depoRes,"DepoRes");

        {
            let data = await farming.getUserInfo.call(toBN(0),accounts[0]);
            expect(data[0]).to.be.eq.BN(depositBalance);
            // expect(data[1]).to.be.eq.BN(toBN(0));
            expect(data[2]).to.be.eq.BN(toBN(0));
        }
        
        //shift some blocks
        await advanceBlock(10);

        {
            let data = await farming.getUserInfo.call(toBN(0),accounts[0]);
            let index=0;
            console.log("amount: ", data[index++].toString());
            console.log("totalRewardClaimed: ", data[index++].toString());
            console.log("withdrawableReward: ", data[index++].toString());
        }

        
        // await time.increase(time.duration.days(1));            

        // {
        //     let data = await farming.getUserInfo.call(toBN(0),accounts[0]);
        //     let index=0;
        //     console.log("amount: ", data[index++].toString());
        //     console.log("totalRewardClaimed: ", data[index++].toString());
        //     console.log("withdrawableReward: ", data[index++].toString());
        // }

        let claimRes = await farming.claimReward.sendTransaction(toBN(0));
        printEvents(claimRes, "claimRes");
        {
            let data = await farming.getUserInfo.call(toBN(0),accounts[0]);
            let index=0;
            console.log("amount: ", data[index++].toString());
            console.log("totalRewardClaimed: ", data[index++].toString());
            console.log("withdrawableReward: ", data[index++].toString());
        }



        await farming.updatePoolData.sendTransaction(toBN(0), toBN(100), farmingStartBlock, farmingEndBlock.add(toBN(1)), toBN(0), toBN(100000).mul(decimals), false);
        await farming.setTokenPerBlock.sendTransaction(totalRewardPerBlock.mul(toBN(2)));
        await advanceBlock(8);



        {
            let data = await farming.getUserInfo.call(toBN(0),accounts[0]);
            let index=0;
            console.log("amount: ", data[index++].toString());
            console.log("totalRewardClaimed: ", data[index++].toString());
            console.log("withdrawableReward: ", data[index++].toString());
        }
        // await farming.deposit.sendTransaction(toBN(0),depositBalance);
        let exitRes = await farming.exit.sendTransaction(toBN(0));
        printEvents(exitRes, "exitRes");
        {
            let data = await farming.getUserInfo.call(toBN(0),accounts[0]);
            let index=0;
            console.log("amount: ", data[index++].toString());
            console.log("totalRewardClaimed: ", data[index++].toString());
            console.log("withdrawableReward: ", data[index++].toString());
        }
        {
            let data = await farming.getPool.call(toBN(0));
            let index=0;
            console.log("token: ", data[index++].toString());
            console.log("share: ", data[index++].toString());
            console.log("startBlock: ", data[index++].toString());
            console.log("endBlock: ", data[index++].toString());
            console.log("lastRewardBlock: ", data[index++].toString());
            console.log("acctPerShare: ", data[index++].toString());
            console.log("totalDeposited: ", data[index++].toString());
        }

        
    });

    

    // it('add Vested Tokens', async () => {
    //     await pureFiToken.transfer.sendTransaction(paymentPlan.address,toBN(100000).mul(decimals));
    //     // vestTokens(uint8 _paymentPlan, uint64 _startDate, uint256 _amount, address _beneficiary)
    //     let totalVested = toBN(100).mul(decimals);
    //     let addVest = await paymentPlan.vestTokens.sendTransaction(toBN(0),startDate,totalVested,accounts[0]);
    //     printEvents(addVest, "addVest");
    
    //     //before start
    //     {
    //         let withdrawable = await paymentPlan.withdrawableAmount.call(accounts[0]);
    //         let nextUnlockDate = withdrawable[0].toNumber();
    //         let availableAmount = withdrawable[1];
    //         console.log(nextUnlockDate," ", availableAmount.toString());
    //         expect(availableAmount).to.be.eq.BN(toBN(0));

    //         await expectRevert(
    //             paymentPlan.withdraw(totalVested, {from: accounts[0]}),
    //             'revert'
    //         );
    //     }
    //     //just after start (TGE payment)
    //     await time.increase(time.duration.days(1));
    //     {
    //         let withdrawable = await paymentPlan.withdrawableAmount.call(accounts[0]);
    //         let nextUnlockDate = withdrawable[0].toNumber();
    //         let availableAmount = withdrawable[1];
    //         console.log(nextUnlockDate," ", availableAmount.toString());
    //         expect(availableAmount).to.be.eq.BN(toBN('33000000000000000000'));
    //         //attempt withdraw full amount
    //         await expectRevert(
    //             paymentPlan.withdraw(totalVested, {from: accounts[0]}),
    //             'revert'
    //         );
            
    //         {
    //             let balanceBefore = await pureFiToken.balanceOf(accounts[0]);
    //             await paymentPlan.withdraw(availableAmount, {from: accounts[0]})
    //             let balanceAfter = await pureFiToken.balanceOf(accounts[0]);
    //             expect(balanceAfter.sub(balanceBefore)).to.be.eq.BN(availableAmount);
    //         }
    //     }


    //     //1 month (cliff, no payment)
    //     await time.increase(time.duration.days(30));
    //     {
    //         let withdrawable = await paymentPlan.withdrawableAmount.call(accounts[0]);
    //         let nextUnlockDate = withdrawable[0].toNumber();
    //         let availableAmount = withdrawable[1];
    //         console.log(nextUnlockDate," ", availableAmount.toString());
    //         expect(availableAmount).to.be.eq.BN(toBN('0'));
    //     }
    //     //2 month (1st payout)
    //     await time.increase(time.duration.days(30));
    //     {
    //         let withdrawable = await paymentPlan.withdrawableAmount.call(accounts[0]);
    //         let nextUnlockDate = withdrawable[0].toNumber();
    //         let availableAmount = withdrawable[1];
    //         console.log(nextUnlockDate," ", availableAmount.toString());
    //         expect(availableAmount).to.be.eq.BN(toBN('33500000000000000000'));

    //         await expectRevert(
    //             paymentPlan.withdraw(totalVested, {from: accounts[0]}),
    //             'revert'
    //         );
            
    //         {
    //             let balanceBefore = await pureFiToken.balanceOf(accounts[0]);
    //             await paymentPlan.withdraw(availableAmount, {from: accounts[0]})
    //             let balanceAfter = await pureFiToken.balanceOf(accounts[0]);
    //             expect(balanceAfter.sub(balanceBefore)).to.be.eq.BN(availableAmount);
    //         }
    //     }
    //     //3 month (2nd payment - full amount)
    //     await time.increase(time.duration.days(30));
    //     {
    //         let withdrawable = await paymentPlan.withdrawableAmount.call(accounts[0]);
    //         let nextUnlockDate = withdrawable[0].toNumber();
    //         let availableAmount = withdrawable[1];
    //         console.log(nextUnlockDate," ", availableAmount.toString());
    //         expect(availableAmount).to.be.eq.BN(toBN('33500000000000000000'));

    //         await expectRevert(
    //             paymentPlan.withdraw(totalVested, {from: accounts[0]}),
    //             'revert'
    //         );
            
    //         {
    //             let balanceBefore = await pureFiToken.balanceOf(accounts[0]);
    //             await paymentPlan.withdraw(availableAmount, {from: accounts[0]})
    //             let balanceAfter = await pureFiToken.balanceOf(accounts[0]);
    //             expect(balanceAfter.sub(balanceBefore)).to.be.eq.BN(availableAmount);
    //         }
    //     }

    //     {
    //         let withdrawable = await paymentPlan.withdrawableAmount.call(accounts[0]);
    //         let nextUnlockDate = withdrawable[0].toNumber();
    //         let availableAmount = withdrawable[1];
    //         console.log(nextUnlockDate," ", availableAmount.toString());
    //         expect(availableAmount).to.be.eq.BN(toBN('0'));
    //     }


  
    // });


    
   
});
