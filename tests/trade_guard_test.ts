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
    name: "Can initiate and resolve dispute",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        const wallet1 = accounts.get("wallet_1")!;
        const wallet2 = accounts.get("wallet_2")!;
        
        // Create and accept trade
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
        
        // Initiate dispute
        let disputeBlock = chain.mineBlock([
            Tx.contractCall("trade_guard", "initiate-dispute", [
                types.uint(1),
                types.utf8("Items not as described")
            ], wallet2.address)
        ]);
        
        disputeBlock.receipts[0].result.expectOk().expectBool(true);
        
        // Resolve dispute
        let resolveBlock = chain.mineBlock([
            Tx.contractCall("trade_guard", "resolve-dispute", [
                types.uint(1),
                types.principal(wallet2.address)
            ], deployer.address)
        ]);
        
        resolveBlock.receipts[0].result.expectOk().expectBool(true);
        
        // Verify final status
        let statusBlock = chain.mineBlock([
            Tx.contractCall("trade_guard", "get-trade-status", [
                types.uint(1)
            ], wallet1.address)
        ]);
        
        statusBlock.receipts[0].result.expectOk().expectAscii("RESOLVED");
    }
});

Clarinet.test({
    name: "Only contract owner can resolve disputes",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get("wallet_1")!;
        const wallet2 = accounts.get("wallet_2")!;
        
        // Create and accept trade
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
        
        // Initiate dispute
        let disputeBlock = chain.mineBlock([
            Tx.contractCall("trade_guard", "initiate-dispute", [
                types.uint(1),
                types.utf8("Items not as described")
            ], wallet2.address)
        ]);
        
        // Try to resolve dispute as non-owner
        let resolveBlock = chain.mineBlock([
            Tx.contractCall("trade_guard", "resolve-dispute", [
                types.uint(1),
                types.principal(wallet2.address)
            ], wallet1.address)
        ]);
        
        resolveBlock.receipts[0].result.expectErr(100); // ERR-UNAUTHORIZED
    }
});
