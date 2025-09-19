;; Marketplace Exchange Contract
;; Automated market maker for carbon credit token trading
;; Implements constant product formula (x * y = k) for price discovery

;; Constants and Error Codes
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u200))
(define-constant ERR-INSUFFICIENT-LIQUIDITY (err u201))
(define-constant ERR-INVALID-AMOUNT (err u202))
(define-constant ERR-SLIPPAGE-TOO-HIGH (err u203))
(define-constant ERR-INSUFFICIENT-BALANCE (err u204))
(define-constant ERR-TRANSFER-FAILED (err u205))
(define-constant ERR-ZERO-AMOUNT (err u206))
(define-constant ERR-POOL-NOT-INITIALIZED (err u207))
(define-constant ERR-INSUFFICIENT-OUTPUT (err u208))
(define-constant ERR-EXCESSIVE-INPUT (err u209))
(define-constant ERR-LIQUIDITY-CALCULATION-FAILED (err u210))
(define-constant ERR-POOL-ALREADY-EXISTS (err u211))
(define-constant ERR-PAUSED (err u212))

;; Pool Configuration
(define-constant TRADING-FEE-RATE u300) ;; 0.3% trading fee (300 basis points)
(define-constant LP-FEE-RATE u250)      ;; 0.25% goes to LPs (250 basis points)
(define-constant PROTOCOL-FEE-RATE u50) ;; 0.05% protocol fee (50 basis points)
(define-constant FEE-DENOMINATOR u100000) ;; 100,000 basis points = 100%
(define-constant MINIMUM-LIQUIDITY u1000) ;; Minimum liquidity to prevent division by zero

;; Data Variables
(define-data-var stx-reserve uint u0)
(define-data-var token-reserve uint u0)
(define-data-var total-lp-tokens uint u0)
(define-data-var pool-initialized bool false)
(define-data-var exchange-paused bool false)
(define-data-var collected-protocol-fees uint u0)
(define-data-var total-volume uint u0)

;; Data Maps
(define-map liquidity-providers principal uint)
(define-map user-trades 
  principal 
  {
    total-trades: uint,
    total-volume: uint,
    last-trade-block: uint
  }
)

;; Helper Functions
(define-private (calculate-stx-output (token-input uint))
  (let
    (
      (token-reserve-current (var-get token-reserve))
      (stx-reserve-current (var-get stx-reserve))
      (token-input-with-fee (- token-input (/ (* token-input TRADING-FEE-RATE) FEE-DENOMINATOR)))
      (numerator (* token-input-with-fee stx-reserve-current))
      (denominator (+ token-reserve-current token-input-with-fee))
    )
    (if (> denominator u0)
      (some (/ numerator denominator))
      none
    )
  )
)

(define-private (calculate-token-output (stx-input uint))
  (let
    (
      (token-reserve-current (var-get token-reserve))
      (stx-reserve-current (var-get stx-reserve))
      (stx-input-with-fee (- stx-input (/ (* stx-input TRADING-FEE-RATE) FEE-DENOMINATOR)))
      (numerator (* stx-input-with-fee token-reserve-current))
      (denominator (+ stx-reserve-current stx-input-with-fee))
    )
    (if (> denominator u0)
      (some (/ numerator denominator))
      none
    )
  )
)

(define-private (calculate-simple-sqrt (n uint))
  ;; Simple approximation of square root
  (if (<= n u1)
    n
    (let ((x (/ n u2)))
      (if (> (* x x) n)
        (- x u1)
        x
      )
    )
  )
)

(define-private (calculate-liquidity-tokens (stx-amount uint) (token-amount uint))
  (let
    (
      (current-total-lp (var-get total-lp-tokens))
      (stx-reserve-current (var-get stx-reserve))
      (token-reserve-current (var-get token-reserve))
    )
    (if (is-eq current-total-lp u0)
      ;; First liquidity provision - simple geometric mean approximation
      (let ((liquidity (calculate-simple-sqrt (* stx-amount token-amount))))
        (if (>= liquidity MINIMUM-LIQUIDITY)
          (some (- liquidity MINIMUM-LIQUIDITY))
          none
        )
      )
      ;; Subsequent liquidity provision - maintain ratio
      (let
        (
          (liquidity-from-stx (/ (* stx-amount current-total-lp) stx-reserve-current))
          (liquidity-from-token (/ (* token-amount current-total-lp) token-reserve-current))
        )
        (some (if (< liquidity-from-stx liquidity-from-token) 
                  liquidity-from-stx 
                  liquidity-from-token))
      )
    )
  )
)

(define-private (record-trade (trader principal) (stx-amount uint) (token-amount uint) (trade-type (string-ascii 10)))
  (let
    (
      (current-trades (default-to {total-trades: u0, total-volume: u0, last-trade-block: u0} 
                                  (map-get? user-trades trader)))
      (trade-volume (+ stx-amount token-amount))
    )
    ;; Update user trade statistics
    (map-set user-trades trader {
      total-trades: (+ (get total-trades current-trades) u1),
      total-volume: (+ (get total-volume current-trades) trade-volume),
      last-trade-block: block-height
    })
    ;; Update total volume
    (var-set total-volume (+ (var-get total-volume) trade-volume))
    (ok true)
  )
)

;; Public Functions
(define-public (initialize-pool (initial-stx uint) (initial-tokens uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (not (var-get pool-initialized)) ERR-POOL-ALREADY-EXISTS)
    (asserts! (and (> initial-stx u0) (> initial-tokens u0)) ERR-ZERO-AMOUNT)
    (asserts! (not (var-get exchange-paused)) ERR-PAUSED)
    
    ;; Transfer STX from sender
    (try! (stx-transfer? initial-stx tx-sender (as-contract tx-sender)))
    
    ;; Calculate initial liquidity tokens
    (let
      (
        (initial-liquidity (calculate-simple-sqrt (* initial-stx initial-tokens)))
        (lp-tokens (- initial-liquidity MINIMUM-LIQUIDITY))
      )
      (asserts! (> lp-tokens u0) ERR-LIQUIDITY-CALCULATION-FAILED)
      
      ;; Update state
      (var-set stx-reserve initial-stx)
      (var-set token-reserve initial-tokens)
      (var-set total-lp-tokens lp-tokens)
      (var-set pool-initialized true)
      (map-set liquidity-providers tx-sender lp-tokens)
      
      (print {
        action: "pool-initialized",
        stx-amount: initial-stx,
        token-amount: initial-tokens,
        lp-tokens: lp-tokens
      })
      (ok lp-tokens)
    )
  )
)

(define-public (add-liquidity (stx-amount uint) (token-amount uint) (min-lp-tokens uint))
  (begin
    (asserts! (var-get pool-initialized) ERR-POOL-NOT-INITIALIZED)
    (asserts! (and (> stx-amount u0) (> token-amount u0)) ERR-ZERO-AMOUNT)
    (asserts! (not (var-get exchange-paused)) ERR-PAUSED)
    
    (let
      (
        (lp-tokens (unwrap! (calculate-liquidity-tokens stx-amount token-amount) 
                           ERR-LIQUIDITY-CALCULATION-FAILED))
        (current-lp-balance (default-to u0 (map-get? liquidity-providers tx-sender)))
      )
      (asserts! (>= lp-tokens min-lp-tokens) ERR-SLIPPAGE-TOO-HIGH)
      
      ;; Transfer STX from user
      (try! (stx-transfer? stx-amount tx-sender (as-contract tx-sender)))
      
      ;; Update reserves and LP tokens
      (var-set stx-reserve (+ (var-get stx-reserve) stx-amount))
      (var-set token-reserve (+ (var-get token-reserve) token-amount))
      (var-set total-lp-tokens (+ (var-get total-lp-tokens) lp-tokens))
      (map-set liquidity-providers tx-sender (+ current-lp-balance lp-tokens))
      
      (print {
        action: "liquidity-added",
        provider: tx-sender,
        stx-amount: stx-amount,
        token-amount: token-amount,
        lp-tokens: lp-tokens
      })
      (ok lp-tokens)
    )
  )
)

(define-public (swap-stx-for-tokens (stx-amount uint) (min-tokens-out uint))
  (begin
    (asserts! (var-get pool-initialized) ERR-POOL-NOT-INITIALIZED)
    (asserts! (> stx-amount u0) ERR-ZERO-AMOUNT)
    (asserts! (not (var-get exchange-paused)) ERR-PAUSED)
    (let
      (
        (token-output (unwrap! (calculate-token-output stx-amount) ERR-INSUFFICIENT-LIQUIDITY))
        (protocol-fee (/ (* stx-amount PROTOCOL-FEE-RATE) FEE-DENOMINATOR))
      )
      (asserts! (>= token-output min-tokens-out) ERR-SLIPPAGE-TOO-HIGH)
      ;; Transfer STX from user
      (try! (stx-transfer? stx-amount tx-sender (as-contract tx-sender)))
      ;; Update reserves
      (var-set stx-reserve (+ (var-get stx-reserve) (- stx-amount protocol-fee)))
      (var-set token-reserve (- (var-get token-reserve) token-output))
      (var-set collected-protocol-fees (+ (var-get collected-protocol-fees) protocol-fee))
      ;; Record trade
      (unwrap-panic (record-trade tx-sender stx-amount token-output "buy"))
      (print {
        action: "tokens-purchased",
        buyer: tx-sender,
        stx-amount: stx-amount,
        token-amount: token-output,
        price: (/ stx-amount token-output)
      })
      (ok token-output)
    )
  )
)

(define-public (swap-tokens-for-stx (token-amount uint) (min-stx-out uint))
  (begin
    (asserts! (var-get pool-initialized) ERR-POOL-NOT-INITIALIZED)
    (asserts! (> token-amount u0) ERR-ZERO-AMOUNT)
    (asserts! (not (var-get exchange-paused)) ERR-PAUSED)
    (let
      (
        (stx-output (unwrap! (calculate-stx-output token-amount) ERR-INSUFFICIENT-LIQUIDITY))
        (protocol-fee (/ (* stx-output PROTOCOL-FEE-RATE) FEE-DENOMINATOR))
        (user-stx-amount (- stx-output protocol-fee))
      )
      (asserts! (>= user-stx-amount min-stx-out) ERR-SLIPPAGE-TOO-HIGH)
      ;; Transfer STX to user (subtract protocol fee)
      (try! (as-contract (stx-transfer? user-stx-amount tx-sender tx-sender)))
      ;; Update reserves
      (var-set stx-reserve (- (var-get stx-reserve) stx-output))
      (var-set token-reserve (+ (var-get token-reserve) token-amount))
      (var-set collected-protocol-fees (+ (var-get collected-protocol-fees) protocol-fee))
      ;; Record trade
      (unwrap-panic (record-trade tx-sender user-stx-amount token-amount "sell"))
      (print {
        action: "tokens-sold",
        seller: tx-sender,
        token-amount: token-amount,
        stx-amount: user-stx-amount,
        price: (/ user-stx-amount token-amount)
      })
      (ok user-stx-amount)
    )
  )
)

;; Administrative Functions
(define-public (pause-exchange)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (var-set exchange-paused true)
    (print {action: "exchange-paused", by: tx-sender})
    (ok true)
  )
)

(define-public (unpause-exchange)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (var-set exchange-paused false)
    (print {action: "exchange-unpaused", by: tx-sender})
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-pool-info)
  {
    stx-reserve: (var-get stx-reserve),
    token-reserve: (var-get token-reserve),
    total-lp-tokens: (var-get total-lp-tokens),
    initialized: (var-get pool-initialized),
    paused: (var-get exchange-paused),
    total-volume: (var-get total-volume)
  }
)

(define-read-only (get-current-price)
  (let
    (
      (stx-reserve-current (var-get stx-reserve))
      (token-reserve-current (var-get token-reserve))
    )
    (if (and (> stx-reserve-current u0) (> token-reserve-current u0))
      (/ stx-reserve-current token-reserve-current)
      u0
    )
  )
)

(define-read-only (get-user-lp-balance (user principal))
  (default-to u0 (map-get? liquidity-providers user))
)

(define-read-only (get-user-trades (user principal))
  (map-get? user-trades user)
)

(define-read-only (calculate-swap-output (input-amount uint) (input-is-stx bool))
  (if input-is-stx
    (calculate-token-output input-amount)
    (calculate-stx-output input-amount)
  )
)

(define-read-only (get-protocol-fees)
  (var-get collected-protocol-fees)
)

(define-read-only (is-exchange-paused)
  (var-get exchange-paused)
)

