;; Stashly - Automated Savings Contract
(define-map savings-accounts
    principal
    { balance: uint,
      last-compound: uint,
      locked-until: uint }
)

(define-data-var total-deposits uint u0)
(define-constant contract-owner tx-sender)
(define-constant min-deposit u1000000) ;; 1 STX minimum
(define-constant compound-interval u144) ;; ~1 day in blocks
(define-constant annual-rate u50) ;; 5% annual rate (basis points)
(define-constant withdrawal-penalty u100) ;; 10% early withdrawal penalty

;; Error codes
(define-constant err-insufficient-funds (err u100))
(define-constant err-min-deposit (err u101))
(define-constant err-still-locked (err u102))
(define-constant err-no-account (err u103))

;; Helper function to calculate interest
(define-private (calculate-interest (principal uint) (blocks uint))
    (let (
        (rate-per-block (/ annual-rate (* u365 u144)))
        (periods (/ blocks compound-interval))
    )
    ;; Simple interest calculation: principal * rate * time
    (/ (* (* principal rate-per-block) blocks) u1000)
    )
)

;; Deposit STX into savings
(define-public (deposit (amount uint))
    (let (
        (existing-account (default-to 
            { balance: u0, last-compound: block-height, locked-until: u0 }
            (map-get? savings-accounts tx-sender)
        ))
    )
    (if (>= amount min-deposit)
        (begin
            (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
            (map-set savings-accounts tx-sender
                (merge existing-account
                    { balance: (+ amount (get balance existing-account)),
                      last-compound: block-height }
                )
            )
            (var-set total-deposits (+ (var-get total-deposits) amount))
            (ok true)
        )
        err-min-deposit
    ))
)

;; Compound interest for an account
(define-public (compound)
    (let (
        (account (unwrap! (map-get? savings-accounts tx-sender) err-no-account))
        (blocks-since-compound (- block-height (get last-compound account)))
        (interest (calculate-interest (get balance account) blocks-since-compound))
    )
    (map-set savings-accounts tx-sender
        (merge account
            { balance: (+ (get balance account) interest),
              last-compound: block-height }
        )
    )
    (ok interest)
    )
)

;; Lock savings for better rate
(define-public (lock-savings (blocks uint))
    (let (
        (account (unwrap! (map-get? savings-accounts tx-sender) err-no-account))
    )
    (map-set savings-accounts tx-sender
        (merge account
            { locked-until: (+ block-height blocks) }
        )
    )
    (ok true)
    )
)

;; Withdraw savings
(define-public (withdraw (amount uint))
    (let (
        (account (unwrap! (map-get? savings-accounts tx-sender) err-no-account))
        (balance (get balance account))
        (locked-until (get locked-until account))
    )
    (if (> locked-until block-height)
        err-still-locked
        (if (>= balance amount)
            (begin
                (try! (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender)))
                (map-set savings-accounts tx-sender
                    (merge account
                        { balance: (- balance amount) }
                    )
                )
                (var-set total-deposits (- (var-get total-deposits) amount))
                (ok true)
            )
            err-insufficient-funds
        )
    ))
)

;; Emergency withdraw with penalty
(define-public (emergency-withdraw)
    (let (
        (account (unwrap! (map-get? savings-accounts tx-sender) err-no-account))
        (balance (get balance account))
        (penalty (/ (* balance withdrawal-penalty) u1000))
        (withdraw-amount (- balance penalty))
    )
    (begin
        (try! (as-contract (stx-transfer? withdraw-amount (as-contract tx-sender) tx-sender)))
        (map-delete savings-accounts tx-sender)
        (var-set total-deposits (- (var-get total-deposits) balance))
        (ok withdraw-amount)
    ))
)

;; Read only functions
(define-read-only (get-balance (account principal))
    (default-to { balance: u0, last-compound: u0, locked-until: u0 }
        (map-get? savings-accounts account))
)

(define-read-only (get-total-deposits)
    (ok (var-get total-deposits))
)