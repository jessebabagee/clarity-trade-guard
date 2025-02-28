// [Previous imports and existing tests remain unchanged]

Clarinet.test({
    name: "Can cancel pending trade",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get("wallet_1")!;
        
        let block = chain.mineBlock([
            Tx.contractCall("trade_guard", "create-trade", [
                types.uint(1000),
                types.utf8("Test trade agreement"),
                types.uint(500)
            ], wallet1.address),
            Tx.contractCall("trade_guard", "cancel-trade", [
                types.uint(1)
            ], wallet1.address)
        ]);
        
        block.receipts[1].result.expectOk().expectBool(true);
    }
});

Clarinet.test({
    name: "Requires both parties to approve completion",
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
        
        // Try to complete without approvals
        let completeBlock = chain.mineBlock([
            Tx.contractCall("trade_guard", "complete-trade", [
                types.uint(1)
            ], wallet1.address)
        ]);
        
        completeBlock.receipts[0].result.expectErr(106); // ERR-NOT-APPROVED
        
        // Approve and complete
        let approvalBlock = chain.mineBlock([
            Tx.contractCall("trade_guard", "approve-completion", [
                types.uint(1)
            ], wallet1.address),
            Tx.contractCall("trade_guard", "approve-completion", [
                types.uint(1)
            ], wallet2.address),
            Tx.contractCall("trade_guard", "complete-trade", [
                types.uint(1)
            ], wallet1.address)
        ]);
        
        approvalBlock.receipts[2].result.expectOk().expectBool(true);
    }
});
