import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensures user can deposit STX",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get('wallet_1')!;
    const deposit_amount = 5000000; // 5 STX

    let block = chain.mineBlock([
      Tx.contractCall('stashly', 'deposit', [
        types.uint(deposit_amount)
      ], wallet_1.address)
    ]);
    
    block.receipts[0].result.expectOk().expectBool(true);
    
    // Verify balance
    let balance_block = chain.mineBlock([
      Tx.contractCall('stashly', 'get-balance', [
        types.principal(wallet_1.address)
      ], wallet_1.address)
    ]);
    
    let balance = balance_block.receipts[0].result;
    assertEquals(balance['balance'], types.uint(deposit_amount));
  },
});

Clarinet.test({
  name: "Ensures minimum deposit is enforced",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get('wallet_1')!;
    const small_deposit = 100; // Below minimum

    let block = chain.mineBlock([
      Tx.contractCall('stashly', 'deposit', [
        types.uint(small_deposit)
      ], wallet_1.address)
    ]);
    
    block.receipts[0].result.expectErr().expectUint(101); // err-min-deposit
  },
});

Clarinet.test({
  name: "Test compound interest calculation",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get('wallet_1')!;
    const deposit_amount = 10000000; // 10 STX

    // Initial deposit
    let deposit = chain.mineBlock([
      Tx.contractCall('stashly', 'deposit', [
        types.uint(deposit_amount)
      ], wallet_1.address)
    ]);

    // Mine some blocks to simulate time passing
    chain.mineEmptyBlockUntil(200);

    // Compound interest
    let compound = chain.mineBlock([
      Tx.contractCall('stashly', 'compound', [], wallet_1.address)
    ]);
    
    compound.receipts[0].result.expectOk();
  },
});

Clarinet.test({
  name: "Test withdrawal with timelock",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet_1 = accounts.get('wallet_1')!;
    const deposit_amount = 5000000; // 5 STX
    const lock_period = 100;

    // Deposit and lock
    let setup = chain.mineBlock([
      Tx.contractCall('stashly', 'deposit', [
        types.uint(deposit_amount)
      ], wallet_1.address),
      Tx.contractCall('stashly', 'lock-savings', [
        types.uint(lock_period)
      ], wallet_1.address)
    ]);

    // Try immediate withdrawal (should fail)
    let early_withdraw = chain.mineBlock([
      Tx.contractCall('stashly', 'withdraw', [
        types.uint(deposit_amount)
      ], wallet_1.address)
    ]);
    
    early_withdraw.receipts[0].result.expectErr().expectUint(102); // err-still-locked

    // Mine blocks past lock period
    chain.mineEmptyBlockUntil(lock_period + 1);

    // Try withdrawal again (should succeed)
    let withdraw = chain.mineBlock([
      Tx.contractCall('stashly', 'withdraw', [
        types.uint(deposit_amount)
      ], wallet_1.address)
    ]);
    
    withdraw.receipts[0].result.expectOk().expectBool(true);
  },
});