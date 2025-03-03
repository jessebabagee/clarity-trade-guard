;; TradeGuard Contract

;; Constants
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-TRADE (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-TRADE-NOT-FOUND (err u103))
(define-constant ERR-INVALID-STATE (err u104))
(define-constant ERR-NO-DISPUTE (err u105))
(define-constant ERR-NOT-APPROVED (err u106))
(define-constant ERR-TRANSFER-FAILED (err u107))
(define-constant DISPUTE-WINDOW u144) ;; ~24 hours in blocks

;; [Previous data structures remain unchanged]

(define-private (is-trade-participant (trade { creator: principal, counterparty: (optional principal) }))
    (match (get counterparty trade)
        counterparty (or
            (is-eq tx-sender (get creator trade))
            (is-eq tx-sender counterparty)
        )
        false
    )
)

;; Enhanced approve-completion with proper validation
(define-public (approve-completion (trade-id uint))
    (let (
        (trade (unwrap! (map-get? trades {trade-id: trade-id}) ERR-TRADE-NOT-FOUND))
        (approvals (default-to 
            { creator-approved: false, counterparty-approved: false }
            (map-get? trade-approvals {trade-id: trade-id})))
        (trade-counterparty (unwrap! (get counterparty trade) ERR-INVALID-TRADE))
    )
        (asserts! (is-eq (get status trade) "ACTIVE") ERR-INVALID-STATE)
        (asserts! (is-trade-participant trade) ERR-UNAUTHORIZED)
        
        (ok (map-set trade-approvals
            {trade-id: trade-id}
            (merge approvals {
                creator-approved: (if (is-eq tx-sender (get creator trade)) true (get creator-approved approvals)),
                counterparty-approved: (if (is-eq tx-sender trade-counterparty) true (get counterparty-approved approvals))
            })
        ))
    )
)

;; Atomic complete-trade implementation
(define-public (complete-trade (trade-id uint))
    (let (
        (trade (unwrap! (map-get? trades {trade-id: trade-id}) ERR-TRADE-NOT-FOUND))
        (approvals (unwrap! (map-get? trade-approvals {trade-id: trade-id}) ERR-NOT-APPROVED))
        (trade-counterparty (unwrap! (get counterparty trade) ERR-INVALID-TRADE))
    )
        (asserts! (is-eq (get status trade) "ACTIVE") ERR-INVALID-STATE)
        (asserts! (and (get creator-approved approvals) (get counterparty-approved approvals)) ERR-NOT-APPROVED)
        
        ;; Update status first
        (map-set trades
            {trade-id: trade-id}
            (merge trade {
                status: "COMPLETED"
            })
        )
        
        ;; Then attempt transfer
        (match (as-contract (stx-transfer? (get escrow-amount trade) tx-sender trade-counterparty))
            success (ok true)
            error (begin
                ;; Rollback on transfer failure
                (map-set trades
                    {trade-id: trade-id}
                    (merge trade {
                        status: "ACTIVE"
                    })
                )
                ERR-TRANSFER-FAILED
            )
        )
    )
)

;; [Other functions remain unchanged]
