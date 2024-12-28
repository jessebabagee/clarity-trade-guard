;; TradeGuard Contract

;; Constants
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-TRADE (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-TRADE-NOT-FOUND (err u103))
(define-constant ERR-INVALID-STATE (err u104))

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
        created-at: uint
    }
)

(define-data-var trade-nonce uint u0)

;; Private Functions
(define-private (generate-trade-id)
    (begin
        (var-set trade-nonce (+ (var-get trade-nonce) u1))
        (var-get trade-nonce)
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
                created-at: block-height
            })
            (ok trade-id)
            ERR-ALREADY-EXISTS
        )
    )
)

(define-public (accept-trade (trade-id uint))
    (let ((trade (unwrap! (map-get? trades {trade-id: trade-id}) ERR-TRADE-NOT-FOUND)))
        (if (is-eq (get status trade) "PENDING")
            (begin 
                (try! (stx-transfer? (get escrow-amount trade) tx-sender (as-contract tx-sender)))
                (map-set trades
                    {trade-id: trade-id}
                    (merge trade {
                        counterparty: (some tx-sender),
                        status: "ACTIVE"
                    })
                )
                (ok true)
            )
            ERR-INVALID-STATE
        )
    )
)

(define-public (complete-trade (trade-id uint))
    (let ((trade (unwrap! (map-get? trades {trade-id: trade-id}) ERR-TRADE-NOT-FOUND)))
        (if (and
            (is-eq (get status trade) "ACTIVE")
            (or
                (is-eq tx-sender (get creator trade))
                (is-eq tx-sender (unwrap! (get counterparty trade) ERR-INVALID-TRADE))
            ))
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

;; Read-only functions
(define-read-only (get-trade (trade-id uint))
    (map-get? trades {trade-id: trade-id})
)

(define-read-only (get-trade-status (trade-id uint))
    (match (map-get? trades {trade-id: trade-id})
        trade (ok (get status trade))
        ERR-TRADE-NOT-FOUND
    )
)