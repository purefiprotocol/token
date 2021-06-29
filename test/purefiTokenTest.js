
const bigDecimal = require('js-big-decimal');
const web3 = require("web3");
const BN = web3.utils.BN;
const chai = require('chai');
const expect = chai.expect;
const assert = chai.assert;
chai.use(require('bn-chai')(BN));
chai.use(require('chai-match'));



const PureFiToken = artifacts.require('PureFiToken');

function toBN(number) {
    return web3.utils.toBN(number);
}


contract('PureFiToken', (accounts) => {
 
    let admin   = accounts[0];
    const decimals = toBN(10).pow(toBN(18));
  
    console.log("Test: Admin: "+admin);

    let pureFiToken;


    before(async () => {
        await PureFiToken.deployed().then(instance => pureFiToken = instance);
    });

    it('PureFi Token', async () => {

        let balance = await pureFiToken.balanceOf.call(admin);
        expect(balance).to.be.eq.BN(toBN(100000000).mul(decimals));
  
    });
   
});
