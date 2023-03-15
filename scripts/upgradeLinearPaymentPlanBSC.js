const PureFiLinearPaymentPlan = artifacts.require('PureFiLinearPaymentPlan');
const pureFiLinearPaymentPlan2BSC = artifacts.require('pureFiLinearPaymentPlan2BSC');
const PProxyAdmin = artifacts.require('PProxyAdmin');

module.exports = async function(callback) {
    
    let owner = "0xcE14bda2d2BceC5247C97B65DBE6e6E570c4Bb6D";
    // web3.eth.sendTransaction({
    //     from:'0x1CA6014f2D372711D97dBf410ac68e408ea0b5c1',
    //     to: owner,
    //     value: web3.utils.toWei("10.0", "ether")
    // })
    // console.log(await web3.eth.getBalance(owner))
    // console.log(await pureFiLinearPaymentPlan2BSC.new.estimateGas())
    let logic = await pureFiLinearPaymentPlan2BSC.new( { from: owner } );
    let admin = await PProxyAdmin.at("0x53e23e7a1e9f680ce6e28a9713f84b89292f0217");
    let proxy = "0xafAb7848AaB0F9EEF9F9e29a83BdBBBdDE02ECe5";
    let pureFiLinearPaymentPlan = await PureFiLinearPaymentPlan.at(proxy);

    let source = "0x756DBeB8568B6BC58BA85966656e678CF8719A0b";
    let destination = "0xcE14bda2d2BceC5247C97B65DBE6e6E570c4Bb6D";
    console.log("before replacing")
    console.log("source: ", await pureFiLinearPaymentPlan.vestingData(source))
    console.log("destination: ")
    try {
        await pureFiLinearPaymentPlan.vestingData(destination)
    }
    catch(e) {
        console.log("no tokens vested")
    }
    console.log("upgrading")

    await admin.upgrade(proxy, logic.address, { from: owner } );
    let pureFiLinearPaymentPlan2BSCpureFiLinearPaymentPlan2BSC = await pureFiLinearPaymentPlan2BSC.at(proxy);
    await pureFiLinearPaymentPlan2BSCpureFiLinearPaymentPlan2BSC.replaceVestingData( { from: owner } );
    // await pureFiLinearPaymentPlan2BSCpureFiLinearPaymentPlan2BSC.unpause( { from: owner } );

    console.log("after replacing")
    console.log("source: ")
    try {
        await pureFiLinearPaymentPlan.vestingData(source)
    }
    catch(e) {
        console.log("no tokens vested")
    }
    console.log("destination: ", await pureFiLinearPaymentPlan2BSCpureFiLinearPaymentPlan2BSC.vestingData(destination))
  
    // invoke callback
    callback();
  }