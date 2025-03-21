;; token.clar
;; Implements the fungible token used for staking and payments

(define-fungible-token data-compute-token)

(define-data-var token-uri (string-utf8 256) u"https://datacomputechain.org/token-metadata.json")

;; Initial supply and distribution
(define-constant contract-owner tx-sender)
(define-constant initial-supply u1000000000) ;; 1 billion tokens

;; Initialize the token
(begin
  (try! (ft-mint? data-compute-token initial-supply contract-owner))
)

;; Standard FT functions
(define-public (transfer (amount uint) (sender principal) (recipient principal))
  (ft-transfer? data-compute-token amount sender recipient)
)

(define-read-only (get-name)
  (ok "DataComputeChain Token")
)

(define-read-only (get-symbol)
  (ok "DCT")
)

(define-read-only (get-decimals)
  (ok u6)
)

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance data-compute-token account))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply data-compute-token))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

;; Owner-only function to update token URI
(define-public (set-token-uri (new-uri (string-utf8 256)))
  (if (is-eq tx-sender contract-owner)
      (begin
        (var-set token-uri new-uri)
        (ok true)
      )
      (err u403)
  )
)

;; Mint new tokens (governance controlled)
(define-public (mint (amount uint) (recipient principal))
  (if (is-eq tx-sender contract-owner)
      (ft-mint? data-compute-token amount recipient)
      (err u403)
  )
)

;; Burn tokens
(define-public (burn (amount uint) (sender principal))
  (ft-burn? data-compute-token amount sender)
)