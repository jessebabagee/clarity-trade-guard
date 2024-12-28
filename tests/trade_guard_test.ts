import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can create a new trade",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get("wallet_1")!;
        
        let block = chain.mineBlock([
            Tx.contractCall("trade_guard", "create-trade", [
                types.uint(1000),
                types.utf8("Test trade agreement"),
                types.uint(500)
            ], wallet1.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.height, 2);
        block.receipts[0].result.expectOk().expectUint(1);
    }
});

Clarinet.test({
    name: "Can accept trade and deposit escrow",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get("wallet_1")!;
        const wallet2 = accounts.get("wallet_2")!;
        
        // First create a trade
        let block = chain.mineBlock([
            Tx.contractCall("trade_guard", "create-trade", [
                types.uint(1000),
                types.utf8("Test trade agreement"),
                types.uint(500)
            ], wallet1.address)
        ]);
        
        // Then accept it
        let acceptBlock = chain.mineBlock([
            Tx.contractCall("trade_guard", "accept-trade", [
                types.uint(1)
            ], wallet2.address)
        ]);
        
        acceptBlock.receipts[0].result.expectOk().expectBool(true);
        
        // Verify trade status
        let statusBlock = chain.mineBlock([
            Tx.contractCall("trade_guard", "get-trade-status", [
                types.uint(1)
            ], wallet1.address)
        ]);
        
        statusBlock.receipts[0].result.expectOk().expectAscii("ACTIVE");
    }
});

Clarinet.test({
    name: "Can complete trade and release escrow",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get("wallet_1")!;
        const wallet2 = accounts.get("wallet_2")!;
        
        // Setup: Create and accept trade
        let setup = chain.mineBlock([
            Tx.contractCall("trade_guard", "create-trade", [
                types.uint(1000),
                types.utf8("Test trade agreement"),
                types.uint(500)
            ], wallet1.address),
            Tx.contractCall("trade_guard", "accept-trade", [
                types.uint(1)
            ], wallet2.address)
        ]);
        
        // Complete trade
        let completeBlock = chain.mineBlock([
            Tx.contractCall("trade_guard", "complete-trade", [
                types.uint(1)
            ], wallet1.address)
        ]);
        
        completeBlock.receipts[0].result.expectOk().expectBool(true);
        
        // Verify final status
        let statusBlock = chain.mineBlock([
            Tx.contractCall("trade_guard", "get-trade-status", [
                types.uint(1)
            ], wallet1.address)
        ]);
        
        statusBlock.receipts[0].result.expectOk().expectAscii("COMPLETED");
    }
});