;; Carbon Credit Token Contract
;; Implements SIP-010 compliant fungible token for carbon credits
;; Each token represents one verified carbon credit (metric ton of CO2 equivalent)

;; Constants and Error Codes
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-BALANCE (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-TOKEN-ALREADY-EXISTS (err u103))
(define-constant ERR-INVALID-RECIPIENT (err u104))
(define-constant ERR-TRANSFER-FAILED (err u105))
(define-constant ERR-MINT-FAILED (err u106))
(define-constant ERR-BURN-FAILED (err u107))
(define-constant ERR-ZERO-AMOUNT (err u108))
(define-constant ERR-SELF-TRANSFER (err u109))

;; Token Metadata
(define-constant TOKEN-NAME "Carbon Credit Token")
(define-constant TOKEN-SYMBOL "CCT")
(define-constant TOKEN-DECIMALS u6)
(define-constant TOKEN-URI "https://carbonmarketplace.org/metadata")

;; Data Variables
(define-data-var token-total-supply uint u0)
(define-data-var contract-paused bool false)
(define-data-var mint-limit-per-tx uint u1000000) ;; 1 million tokens per tx

;; Data Maps
(define-map token-balances principal uint)
(define-map token-allowances {owner: principal, spender: principal} uint)
(define-map verified-minters principal bool)
(define-map carbon-credit-metadata 
  uint 
  {
    project-id: (string-ascii 64),
    vintage-year: uint,
    methodology: (string-ascii 32),
    verification-body: (string-ascii 64),
    issuance-date: uint,
    retirement-status: bool
  }
)
(define-map token-transfers {from: principal, to: principal, amount: uint} uint)

;; Private Functions
(define-private (get-balance-or-default (account principal))
  (default-to u0 (map-get? token-balances account))
)

(define-private (get-allowance-or-default (owner principal) (spender principal))
  (default-to u0 (map-get? token-allowances {owner: owner, spender: spender}))
)

(define-private (set-balance (account principal) (new-balance uint))
  (begin
    (if (> new-balance u0)
      (map-set token-balances account new-balance)
      (map-delete token-balances account)
    )
    (ok true)
  )
)

(define-private (validate-transfer (sender principal) (recipient principal) (amount uint))
  (and 
    (> amount u0)
    (not (is-eq sender recipient))
    (>= (get-balance-or-default sender) amount)
    (not (var-get contract-paused))
  )
)

(define-private (execute-transfer (sender principal) (recipient principal) (amount uint))
  (let 
    (
      (sender-balance (get-balance-or-default sender))
      (recipient-balance (get-balance-or-default recipient))
    )
    (unwrap-panic (set-balance sender (- sender-balance amount)))
    (unwrap-panic (set-balance recipient (+ recipient-balance amount)))
    (map-set token-transfers {from: sender, to: recipient, amount: amount} block-height)
    (print {action: "transfer", from: sender, to: recipient, amount: amount, block: block-height})
    (ok true)
  )
)

;; SIP-010 Required Functions
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR-UNAUTHORIZED)
    (asserts! (validate-transfer sender recipient amount) ERR-TRANSFER-FAILED)
    (unwrap-panic (execute-transfer sender recipient amount))
    (match memo
      value true
      true
    )
    (ok true)
  )
)

(define-read-only (get-name)
  (ok TOKEN-NAME)
)

(define-read-only (get-symbol)
  (ok TOKEN-SYMBOL)
)

(define-read-only (get-decimals)
  (ok TOKEN-DECIMALS)
)

(define-read-only (get-balance (account principal))
  (ok (get-balance-or-default account))
)

(define-read-only (get-total-supply)
  (ok (var-get token-total-supply))
)

(define-read-only (get-token-uri)
  (ok (some TOKEN-URI))
)

;; Extended Token Functions
(define-public (mint (recipient principal) (amount uint))
  (let
    (
      (current-balance (get-balance-or-default recipient))
      (current-supply (var-get token-total-supply))
    )
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) 
                  (default-to false (map-get? verified-minters tx-sender))) ERR-UNAUTHORIZED)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (asserts! (<= amount (var-get mint-limit-per-tx)) ERR-INVALID-AMOUNT)
    (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
    
    (unwrap-panic (set-balance recipient (+ current-balance amount)))
    (var-set token-total-supply (+ current-supply amount))
    (print {action: "mint", to: recipient, amount: amount, block: block-height})
    (ok amount)
  )
)

(define-public (burn (amount uint))
  (let
    (
      (current-balance (get-balance-or-default tx-sender))
      (current-supply (var-get token-total-supply))
    )
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (asserts! (>= current-balance amount) ERR-INSUFFICIENT-BALANCE)
    (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
    
    (unwrap-panic (set-balance tx-sender (- current-balance amount)))
    (var-set token-total-supply (- current-supply amount))
    (print {action: "burn", from: tx-sender, amount: amount, block: block-height})
    (ok amount)
  )
)

;; Allowance Functions
(define-public (approve (spender principal) (amount uint))
  (begin
    (asserts! (not (is-eq tx-sender spender)) ERR-INVALID-RECIPIENT)
    (map-set token-allowances {owner: tx-sender, spender: spender} amount)
    (print {action: "approve", owner: tx-sender, spender: spender, amount: amount})
    (ok true)
  )
)

(define-read-only (get-allowance (owner principal) (spender principal))
  (ok (get-allowance-or-default owner spender))
)

(define-public (transfer-from (sender principal) (recipient principal) (amount uint))
  (let
    (
      (allowance (get-allowance-or-default sender tx-sender))
    )
    (asserts! (>= allowance amount) ERR-UNAUTHORIZED)
    (asserts! (validate-transfer sender recipient amount) ERR-TRANSFER-FAILED)
    
    (unwrap-panic (execute-transfer sender recipient amount))
    (map-set token-allowances 
             {owner: sender, spender: tx-sender} 
             (- allowance amount))
    (ok true)
  )
)

;; Administrative Functions
(define-public (add-verified-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (map-set verified-minters minter true)
    (print {action: "add-minter", minter: minter})
    (ok true)
  )
)

(define-public (remove-verified-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (map-delete verified-minters minter)
    (print {action: "remove-minter", minter: minter})
    (ok true)
  )
)

(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (var-set contract-paused true)
    (print {action: "contract-paused", by: tx-sender})
    (ok true)
  )
)

(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (var-set contract-paused false)
    (print {action: "contract-unpaused", by: tx-sender})
    (ok true)
  )
)

(define-public (set-mint-limit (new-limit uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (> new-limit u0) ERR-INVALID-AMOUNT)
    (var-set mint-limit-per-tx new-limit)
    (print {action: "mint-limit-updated", new-limit: new-limit})
    (ok true)
  )
)

;; Carbon Credit Metadata Functions
(define-public (set-carbon-credit-metadata 
  (token-id uint)
  (project-id (string-ascii 64))
  (vintage-year uint)
  (methodology (string-ascii 32))
  (verification-body (string-ascii 64))
)
  (begin
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) 
                  (default-to false (map-get? verified-minters tx-sender))) ERR-UNAUTHORIZED)
    (map-set carbon-credit-metadata token-id {
      project-id: project-id,
      vintage-year: vintage-year,
      methodology: methodology,
      verification-body: verification-body,
      issuance-date: block-height,
      retirement-status: false
    })
    (print {action: "metadata-set", token-id: token-id, project-id: project-id})
    (ok true)
  )
)

(define-read-only (get-carbon-credit-metadata (token-id uint))
  (map-get? carbon-credit-metadata token-id)
)

(define-public (retire-carbon-credit (token-id uint))
  (let
    (
      (metadata (unwrap! (map-get? carbon-credit-metadata token-id) ERR-INVALID-AMOUNT))
    )
    (asserts! (not (get retirement-status metadata)) ERR-INVALID-AMOUNT)
    (map-set carbon-credit-metadata token-id (merge metadata {retirement-status: true}))
    (print {action: "carbon-credit-retired", token-id: token-id, by: tx-sender})
    (ok true)
  )
)

;; Read-only Helper Functions
(define-read-only (is-contract-paused)
  (var-get contract-paused)
)

(define-read-only (is-verified-minter (minter principal))
  (default-to false (map-get? verified-minters minter))
)

(define-read-only (get-mint-limit)
  (var-get mint-limit-per-tx)
)

(define-read-only (get-transfer-history (sender principal) (recipient principal) (amount uint))
  (map-get? token-transfers {from: sender, to: recipient, amount: amount})
)


;; title: carbon-credit-token
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

