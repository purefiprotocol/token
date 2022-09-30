# PureFi Token Ecosystem

## Ethereum Mainnet

1. UFI Token contract: [0xcDa4e840411C00a614aD9205CAEC807c7458a0E3](https://etherscan.io/token/0xcDa4e840411C00a614aD9205CAEC807c7458a0E3)
1. Payment Plan contract (Fixed Dates unlock): [0xDeE6e64F14f51BeDD3AB76DBb9DBAD1762c5Ea4b](https://etherscan.io/address/0xDeE6e64F14f51BeDD3AB76DBb9DBAD1762c5Ea4b)
1. Payment Plan contract (Linear unlock): [0xF9da2dE9E04561f69AB770a846eE7DDCfc2c53F6](https://etherscan.io/address/0xF9da2dE9E04561f69AB770a846eE7DDCfc2c53F6)
1. Farming contract: [0xafAb7848AaB0F9EEF9F9e29a83BdBBBdDE02ECe5](https://etherscan.io/address/0xafAb7848AaB0F9EEF9F9e29a83BdBBBdDE02ECe5)

## Binance Smart Chain

1. UFI Token contract: [0xe2a59D5E33c6540E18aAA46BF98917aC3158Db0D](https://bscscan.com/token/0xe2a59D5E33c6540E18aAA46BF98917aC3158Db0D)
1. Payment Plan contract (Fixed Dates unlock): [0x9ed4B0a2B8345EEb1e43A4D0298e351fc320D278](https://bscscan.com/address/0x9ed4B0a2B8345EEb1e43A4D0298e351fc320D278)
1. Payment Plan contract (Linear unlock): [0xafAb7848AaB0F9EEF9F9e29a83BdBBBdDE02ECe5](https://bscscan.com/address/0xafAb7848AaB0F9EEF9F9e29a83BdBBBdDE02ECe5)
1. Farming contract: [0x33f86fDc03387A066c4395677658747c696932Eb](https://bscscan.com/address/0x33f86fDc03387A066c4395677658747c696932Eb)

## Polygon

1. UFI Token contract: [0x3c205C8B3e02421Da82064646788c82f7bd753B9](https://polygonscan.com/token/0x3c205C8B3e02421Da82064646788c82f7bd753B9)

# PureFi Token codebase

Token codebase is Truffle based. 

`npm i` then `truffle compile`

## Pure FI Token contract
PureFi ERC20 Token implementation is based on the Open Zeppelin contracts.

Features:
- Pausable
- ACL Enabled
- Integrated Bot Protection 

## Payment plan with fixed date unlocks

The payment plan is designed for vesting tokens that unlock on exact dates.

## Payment plan with linear unlocks
 
The payment plan is designed for vesting tokens with a cliff, and linear unlock every time (specified by the `period` parameter) with exact percentage until 100% are unlocked.

## Farming contract

PureFi farming is designed to reward a fixed amount of tokens per block. Therefore, APY would be dynamic and based on users who staked their tokens on the Farming contract. The farming contract supports farming in multiple pools with different liquidity tokens
