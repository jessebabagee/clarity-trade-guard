;; TradeGuard Contract

;; Constants
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-TRADE (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-TRADE-NOT-FOUND (err u103))
(define-constant ERR-INVALID-STATE (err u104))
(define-constant ERR-NO-DISPUTE (err u105))
(define-constant ERR-NOT-APPROVED (err u106))
(define-constant DISPUTE-WINDOW u144) ;; ~24 hours in blocks

;; Data Variables
(define-map trades
    { trade-id: uint }
    {
        creator: principal,
        counterparty: (optional principal),
        amount: uint,
        description: (string-utf8 256),
        status: (string-ascii 20),
        escrow-amount: uint,
        created-at: uint,
        dispute: (optional {
            initiated-by: principal,
            reason: (string-utf8 256),
            initiated-at: uint
        })
    }
)

(define-map trade-approvals
    { trade-id: uint }
    {
        creator-approved: bool,
        counterparty-approved: bool
    }
)

(define-data-var trade-nonce uint u0)
(define-data-var contract-owner principal tx-sender)

;; Private Functions
(define-private (generate-trade-id)
    (begin
        (var-set trade-nonce (+ (var-get trade-nonce) u1))
        (var-get trade-nonce)
    )
)

(define-private (is-contract-owner)
    (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-trade-participant (trade { creator: principal, counterparty: (optional principal) }))
    (or
        (is-eq tx-sender (get creator trade))
        (is-eq tx-sender (unwrap! (get counterparty trade) false))
    )
)

;; Public Functions
(define-public (create-trade (amount uint) (description (string-utf8 256)) (escrow-amount uint))
    (let ((trade-id (generate-trade-id)))
        (match (map-insert trades
            { trade-id: trade-id }
            {
                creator: tx-sender,
                counterparty: none,
                amount: amount,
                description: description,
                status: "PENDING",
                escrow-amount: escrow-amount,
                created-at: block-height,
                dispute: none
            })
            (ok trade-id)
            ERR-ALREADY-EXISTS
        )
    )
)

(define-public (cancel-trade (trade-id uint))
    (let ((trade (unwrap! (map-get? trades {trade-id: trade-id}) ERR-TRADE-NOT-FOUND)))
        (if (and
            (is-eq (get status trade) "PENDING")
            (is-eq tx-sender (get creator trade)))
            (begin
                (map-set trades
                    {trade-id: trade-id}
                    (merge trade {
                        status: "CANCELLED"
                    })
                )
                (ok true)
            )
            ERR-INVALID-STATE
        )
    )
)

(define-public (approve-completion (trade-id uint))
    (let ((trade (unwrap! (map-get? trades {trade-id: trade-id}) ERR-TRADE-NOT-FOUND))
          (approvals (default-to 
              { creator-approved: false, counterparty-approved: false }
              (map-get? trade-approvals {trade-id: trade-id}))))
        (if (and
            (is-eq (get status trade) "ACTIVE")
            (is-trade-participant trade))
            (begin
                (map-set trade-approvals
                    {trade-id: trade-id}
                    (merge approvals {
                        creator-approved: (if (is-eq tx-sender (get creator trade)) true (get creator-approved approvals)),
                        counterparty-approved: (if (is-eq tx-sender (unwrap! (get counterparty trade) false)) true (get counterparty-approved approvals))
                    })
                )
                (ok true)
            )
            ERR-INVALID-STATE
        )
    )
)

;; [Previous functions remain unchanged: accept-trade, initiate-dispute, resolve-dispute]

(define-public (complete-trade (trade-id uint))
    (let ((trade (unwrap! (map-get? trades {trade-id: trade-id}) ERR-TRADE-NOT-FOUND))
          (approvals (unwrap! (map-get? trade-approvals {trade-id: trade-id}) ERR-NOT-APPROVED)))
        (if (and
            (is-eq (get status trade) "ACTIVE")
            (get creator-approved approvals)
            (get counterparty-approved approvals))
            (begin
                (try! (as-contract (stx-transfer? (get escrow-amount trade) tx-sender (unwrap! (get counterparty trade) ERR-INVALID-TRADE))))
                (map-set trades
                    {trade-id: trade-id}
                    (merge trade {
                        status: "COMPLETED"
                    })
                )
                (ok true)
            )
            ERR-INVALID-STATE
        )
    )
)

;; [Previous read-only functions remain unchanged]
