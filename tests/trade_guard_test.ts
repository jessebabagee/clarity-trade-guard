// [Previous imports remain unchanged]

Clarinet.test({
    name: "Handles failed transfers correctly in complete-trade",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get("wallet_1")!;
        const wallet2 = accounts.get("wallet_2")!;
        
        // Setup trade and approvals
        let setup = chain.mineBlock([
            Tx.contractCall("trade_guard", "create-trade", [
                types.uint(1000000000), // Very large amount to cause failure
                types.utf8("Test trade agreement"),
                types.uint(500000000)
            ], wallet1.address),
            Tx.contractCall("trade_guard", "accept-trade", [
                types.uint(1)
            ], wallet2.address)
        ]);
        
        // Approve completion
        let approvalBlock = chain.mineBlock([
            Tx.contractCall("trade_guard", "approve-completion", [
                types.uint(1)
            ], wallet1.address),
            Tx.contractCall("trade_guard", "approve-completion", [
                types.uint(1)
            ], wallet2.address)
        ]);
        
        // Attempt completion
        let completeBlock = chain.mineBlock([
            Tx.contractCall("trade_guard", "complete-trade", [
                types.uint(1)
            ], wallet1.address)
        ]);
        
        completeBlock.receipts[0].result.expectErr(107); // ERR-TRANSFER-FAILED
    }
});

// [Previous tests remain unchanged]
