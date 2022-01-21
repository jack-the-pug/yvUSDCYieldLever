# yvUSDC YieldLever

Yield Protocol Bounty: Leveraged Borrowing using yvUSDC collateral

## How to use it?

0. Deploy;
1. Approve USDC to the `YieldLever` contract;
2. Call `invest()`, sample calldata:
```json
{
  "baseAmount": "250000000000",
  "borrowAmount": "750000000000",
  "maxFyAmount": "757000000000",
  "seriesId": "0x303230350000"
}
```
3. For exit, call `unwind()`, sample calldata:
```json
{
  "vaultId": "0x2db8ebe62e77e730a70af447",
  "maxAmount": "757000000000",
  "pool": "0x80142add3a597b1ed1de392a56b2cef3d8302797",
  "ink": "-991394806555",
  "art": "0"
}
```
4. For exit after maturity, call `unwind()` with maxAmount set to `0`, sample calldata:
```json
{
  "vaultId": "0x2db8ebe62e77e730a70af447",
  "maxAmount": "0",
  "pool": "0x80142add3a597b1ed1de392a56b2cef3d8302797",
  "ink": "-991394806555",
  "art": "-755561186516"
}
```


## How it works?

### For invest:

1. Start with 250k USDC and Borrow 750k USDC (flash loan from BZX);
2. Deposit into the yvUSDC vault (earning ~5%);
3. Use the yvUSDC to borrow 750K of USDC on Yield at 2.5%;
4. Repay your 750k USDC loan.

### For unwind:

1. Borrow ~757k USDC (flash loan from BZX);
2. Repay Yield loan and get yvUSDC back;
3. Withdraw USDC from yvUSDC;
4. Repay flash loan.

## ☎️

Contact me on Discord: JTP#3209
