;; dataset-quality.clar
;; Implements dataset quality assurance protocol with staking and slashing mechanisms

(define-data-var minimum-stake uint u1000)
(define-data-var contract-owner principal tx-sender)
(define-map authorized-slashers principal bool)
(define-map dataset-stakes { provider: principal, dataset-id: (string-ascii 64) } { stake-amount: uint, release-schedule: (list 10 { milestone: uint, percentage: uint }) })
(define-map dataset-quality-scores { dataset-id: (string-ascii 64) } { score: uint, reviews: (list 50 { reviewer: principal, score: uint, timestamp: uint }) })

;; Initialize authorized slashers
(begin
  (map-set authorized-slashers tx-sender true)
)

;; Function to add authorized slasher (only owner can call)
(define-public (add-authorized-slasher (slasher principal))
  (if (is-eq tx-sender (var-get contract-owner))
      (begin
        (map-set authorized-slashers slasher true)
        (ok true))
      (err u100)))

;; Function to stake tokens for a dataset
(define-public (stake-for-dataset (dataset-id (string-ascii 64)) (stake-amount uint))
  (let ((current-stake (default-to u0 (get stake-amount (map-get? dataset-stakes { provider: tx-sender, dataset-id: dataset-id })))))
    (if (>= stake-amount (var-get minimum-stake))
        (begin
          (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
          (map-set dataset-stakes 
            { provider: tx-sender, dataset-id: dataset-id } 
            { 
              stake-amount: (+ current-stake stake-amount), 
              release-schedule: (list 
                { milestone: u25, percentage: u20 }
                { milestone: u50, percentage: u30 }
                { milestone: u75, percentage: u30 }
                { milestone: u100, percentage: u20 }
              ) 
            })
          (ok true))
        (err u1))))

;; Function to report dataset issues
(define-public (report-issue (dataset-id (string-ascii 64)) (issue-type uint) (evidence (string-utf8 1024)))
  (let ((dataset-entry (map-get? dataset-stakes { provider: tx-sender, dataset-id: dataset-id })))
    (if (is-some dataset-entry)
        (begin
          ;; Logic for issue verification would go here
          ;; For now, we'll just emit an event
          (print { event: "issue-reported", dataset-id: dataset-id, reporter: tx-sender, issue-type: issue-type })
          (ok true))
        (err u2))))

;; Function to slash stake based on verified issues
(define-public (slash-stake (dataset-id (string-ascii 64)) (provider principal) (slash-percentage uint))
  (let ((dataset-entry (map-get? dataset-stakes { provider: provider, dataset-id: dataset-id }))
        (is-authorized (default-to false (map-get? authorized-slashers tx-sender))))
    (if (and is-authorized (is-some dataset-entry))
        (let ((stake-amount (get stake-amount (unwrap-panic dataset-entry)))
              (slash-amount (/ (* stake-amount slash-percentage) u100)))
          ;; Transfer slashed amount to community pool or burn
          (try! (as-contract (stx-transfer? slash-amount tx-sender (var-get contract-owner))))
          (map-set dataset-stakes 
            { provider: provider, dataset-id: dataset-id } 
            { 
              stake-amount: (- stake-amount slash-amount),
              release-schedule: (get release-schedule (unwrap-panic dataset-entry))
            })
          (ok true))
        (err u3))))

;; Function to release tokens based on model performance - FIXED
(define-public (release-stake (dataset-id (string-ascii 64)) (performance-score uint))
  (let ((dataset-entry (map-get? dataset-stakes { provider: tx-sender, dataset-id: dataset-id })))
    (if (is-some dataset-entry)
        (let ((stake-amount (get stake-amount (unwrap-panic dataset-entry)))
              (release-schedule (get release-schedule (unwrap-panic dataset-entry)))
              ;; Calculate release amount directly in the let binding
              (release-amount (/ (* stake-amount performance-score) u100)))
          ;; Now we can use release-amount directly
          (try! (as-contract (stx-transfer? release-amount tx-sender tx-sender)))
          (map-set dataset-stakes 
            { provider: tx-sender, dataset-id: dataset-id } 
            { 
              stake-amount: (- stake-amount release-amount),
              release-schedule: release-schedule
            })
          (ok true))
        (err u4))))