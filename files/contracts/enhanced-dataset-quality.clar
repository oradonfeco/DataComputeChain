;; enhanced-dataset-quality.clar
;; Enhanced dataset quality assurance protocol with reputation system, time-locked staking, 
;; categorization, and standardized quality metrics

(define-data-var minimum-stake uint u1000)
(define-data-var contract-owner principal tx-sender)
(define-data-var reputation-decay-rate uint u5) ;; 5% decay per period
(define-data-var quality-threshold uint u75) ;; Minimum 75% quality score

;; Dataset categories enum (using uint for efficiency)
(define-constant CATEGORY-NLP u1)
(define-constant CATEGORY-COMPUTER-VISION u2)
(define-constant CATEGORY-AUDIO u3)
(define-constant CATEGORY-TIME-SERIES u4)
(define-constant CATEGORY-TABULAR u5)
(define-constant CATEGORY-MULTIMODAL u6)

;; Lock period multipliers (basis points - 10000 = 100%)
(define-constant LOCK-30-DAYS u10500)  ;; 1.05x multiplier
(define-constant LOCK-90-DAYS u11500)  ;; 1.15x multiplier
(define-constant LOCK-180-DAYS u13000) ;; 1.30x multiplier
(define-constant LOCK-365-DAYS u15000) ;; 1.50x multiplier

;; Error codes
(define-constant ERR-INSUFFICIENT-STAKE u1)
(define-constant ERR-UNAUTHORIZED u2)
(define-constant ERR-INVALID-CATEGORY u3)
(define-constant ERR-INVALID-SCORES u4)
(define-constant ERR-DATASET-NOT-FOUND u5)
(define-constant ERR-STAKE-LOCKED u6)
(define-constant ERR-STAKE-NOT-FOUND u7)
(define-constant ERR-INVALID-SLASH-PERCENTAGE u8)
(define-constant ERR-TRANSFER-FAILED u9)
(define-constant ERR-OWNER-ONLY u100)
(define-constant ERR-REVIEWER-ONLY u101)
(define-constant ERR-SLASHER-ONLY u102)

;; Maps for enhanced functionality
(define-map authorized-slashers principal bool)
(define-map authorized-reviewers principal bool)

;; Enhanced dataset stakes with time-locking
(define-map dataset-stakes 
  { provider: principal, dataset-id: (string-ascii 64) } 
  { 
    stake-amount: uint,
    effective-stake: uint, ;; stake-amount * multiplier
    lock-period: uint,
    lock-start: uint,
    unlock-time: uint,
    category: uint,
    release-schedule: (list 10 { milestone: uint, percentage: uint }),
    is-locked: bool
  })

;; Provider reputation system
(define-map provider-reputation 
  { provider: principal }
  {
    total-datasets: uint,
    successful-datasets: uint,
    total-stake-slashed: uint,
    reputation-score: uint, ;; 0-1000 (0-100.0%)
    last-update: uint,
    performance-history: (list 20 { dataset-id: (string-ascii 64), score: uint, timestamp: uint })
  })

;; Enhanced dataset quality metrics
(define-map dataset-quality-metrics 
  { dataset-id: (string-ascii 64) }
  {
    category: uint,
    overall-score: uint,
    completeness-score: uint,
    accuracy-score: uint,
    consistency-score: uint,
    bias-score: uint,
    freshness-score: uint,
    total-reviews: uint,
    weighted-score: uint,
    certification-level: uint, ;; 0=None, 1=Bronze, 2=Silver, 3=Gold
    reviews: (list 50 { 
      reviewer: principal, 
      overall-score: uint,
      completeness: uint,
      accuracy: uint,
      consistency: uint,
      bias: uint,
      freshness: uint,
      timestamp: uint,
      reviewer-weight: uint
    })
  })

;; Category-specific quality requirements
(define-map category-requirements
  { category: uint }
  {
    min-completeness: uint,
    min-accuracy: uint,
    min-consistency: uint,
    max-bias: uint,
    min-freshness: uint,
    required-sample-size: uint
  })

;; Initialize the contract
(begin
  (map-set authorized-slashers tx-sender true)
  (map-set authorized-reviewers tx-sender true)
  ;; Set default category requirements
  (map-set category-requirements { category: CATEGORY-NLP } 
    { min-completeness: u85, min-accuracy: u80, min-consistency: u75, max-bias: u20, min-freshness: u70, required-sample-size: u1000 })
  (map-set category-requirements { category: CATEGORY-COMPUTER-VISION } 
    { min-completeness: u90, min-accuracy: u85, min-consistency: u80, max-bias: u15, min-freshness: u60, required-sample-size: u5000 })
  (map-set category-requirements { category: CATEGORY-AUDIO } 
    { min-completeness: u80, min-accuracy: u75, min-consistency: u70, max-bias: u25, min-freshness: u65, required-sample-size: u2000 })
  (map-set category-requirements { category: CATEGORY-TIME-SERIES } 
    { min-completeness: u95, min-accuracy: u90, min-consistency: u85, max-bias: u10, min-freshness: u80, required-sample-size: u10000 })
  (map-set category-requirements { category: CATEGORY-TABULAR } 
    { min-completeness: u85, min-accuracy: u80, min-consistency: u75, max-bias: u20, min-freshness: u50, required-sample-size: u1000 })
  (map-set category-requirements { category: CATEGORY-MULTIMODAL } 
    { min-completeness: u90, min-accuracy: u85, min-consistency: u80, max-bias: u15, min-freshness: u70, required-sample-size: u3000 })
)

;; Helper function to calculate lock multiplier
(define-private (get-lock-multiplier (lock-period uint))
  (if (is-eq lock-period u30)
      LOCK-30-DAYS
      (if (is-eq lock-period u90)
          LOCK-90-DAYS
          (if (is-eq lock-period u180)
              LOCK-180-DAYS
              (if (is-eq lock-period u365)
                  LOCK-365-DAYS
                  u10000))))) ;; Default 1.0x multiplier

;; Helper function to validate category
(define-private (is-valid-category (category uint))
  (and (>= category u1) (<= category u6)))

;; Helper function to validate scores (0-100)
(define-private (are-valid-scores (completeness uint) (accuracy uint) (consistency uint) (bias uint) (freshness uint))
  (and (<= completeness u100)
       (<= accuracy u100)
       (<= consistency u100)
       (<= bias u100)
       (<= freshness u100)))

;; Function to add authorized reviewer (only owner can call)
(define-public (add-authorized-reviewer (reviewer principal))
  (if (is-eq tx-sender (var-get contract-owner))
      (begin
        (map-set authorized-reviewers reviewer true)
        (ok true))
      (err ERR-OWNER-ONLY)))

;; Function to add authorized slasher (only owner can call)
(define-public (add-authorized-slasher (slasher principal))
  (if (is-eq tx-sender (var-get contract-owner))
      (begin
        (map-set authorized-slashers slasher true)
        (ok true))
      (err ERR-OWNER-ONLY)))

;; Enhanced function to stake tokens for a dataset with time-locking and categorization
(define-public (stake-for-dataset 
                (dataset-id (string-ascii 64)) 
                (stake-amount uint) 
                (lock-period uint) 
                (category uint))
  (let ((current-stake (default-to u0 (get stake-amount (map-get? dataset-stakes { provider: tx-sender, dataset-id: dataset-id }))))
        (multiplier (get-lock-multiplier lock-period))
        (effective-stake (/ (* stake-amount multiplier) u10000))
        (unlock-time (+ stacks-block-height (* lock-period u144)))) ;; Assuming ~10 min blocks, 144 blocks per day
    (asserts! (>= stake-amount (var-get minimum-stake)) (err ERR-INSUFFICIENT-STAKE))
    (asserts! (is-valid-category category) (err ERR-INVALID-CATEGORY))
    
    ;; Transfer stake to contract
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    
    ;; Update dataset stakes
    (map-set dataset-stakes 
      { provider: tx-sender, dataset-id: dataset-id } 
      { 
        stake-amount: (+ current-stake stake-amount),
        effective-stake: (+ current-stake effective-stake),
        lock-period: lock-period,
        lock-start: stacks-block-height,
        unlock-time: unlock-time,
        category: category,
        release-schedule: (list 
          { milestone: u25, percentage: u20 }
          { milestone: u50, percentage: u30 }
          { milestone: u75, percentage: u30 }
          { milestone: u100, percentage: u20 }
        ),
        is-locked: true
      })
    
    ;; Initialize dataset quality metrics
    (map-set dataset-quality-metrics
      { dataset-id: dataset-id }
      {
        category: category,
        overall-score: u0,
        completeness-score: u0,
        accuracy-score: u0,
        consistency-score: u0,
        bias-score: u0,
        freshness-score: u0,
        total-reviews: u0,
        weighted-score: u0,
        certification-level: u0,
        reviews: (list)
      })
    
    (ok true)))

;; Function to submit comprehensive dataset quality review
(define-public (submit-quality-review 
                (dataset-id (string-ascii 64))
                (completeness uint)
                (accuracy uint)
                (consistency uint)
                (bias uint)
                (freshness uint))
  (let ((is-authorized (default-to false (map-get? authorized-reviewers tx-sender)))
        (dataset-metrics (map-get? dataset-quality-metrics { dataset-id: dataset-id }))
        (reviewer-reputation (default-to u100 (get reputation-score (map-get? provider-reputation { provider: tx-sender }))))
        (reviewer-weight (/ reviewer-reputation u10)) ;; Convert to weight (10-100)
        (overall-score (/ (+ completeness accuracy consistency (- u100 bias) freshness) u5)))
    
    (asserts! is-authorized (err ERR-REVIEWER-ONLY))
    (asserts! (is-some dataset-metrics) (err ERR-DATASET-NOT-FOUND))
    (asserts! (are-valid-scores completeness accuracy consistency bias freshness) (err ERR-INVALID-SCORES))
    
    (let ((current-metrics (unwrap! dataset-metrics (err ERR-DATASET-NOT-FOUND)))
          (current-reviews (get reviews current-metrics))
          (total-reviews (+ (get total-reviews current-metrics) u1))
          (new-review { 
            reviewer: tx-sender,
            overall-score: overall-score,
            completeness: completeness,
            accuracy: accuracy,
            consistency: consistency,
            bias: bias,
            freshness: freshness,
            timestamp: stacks-block-height,
            reviewer-weight: reviewer-weight
          })
          (updated-reviews (unwrap! (as-max-len? (append current-reviews new-review) u50) (err ERR-INVALID-SCORES))))
      
      (map-set dataset-quality-metrics
        { dataset-id: dataset-id }
        (merge current-metrics {
          overall-score: overall-score,
          completeness-score: completeness,
          accuracy-score: accuracy,
          consistency-score: consistency,
          bias-score: bias,
          freshness-score: freshness,
          total-reviews: total-reviews,
          weighted-score: (calculate-weighted-score overall-score reviewer-weight),
          certification-level: (determine-certification-level overall-score),
          reviews: updated-reviews
        }))
      
      (ok true))))

;; Helper function to calculate weighted score (simplified)
(define-private (calculate-weighted-score (new-score uint) (reviewer-weight uint))
  ;; Simplified weighted average calculation
  (/ (* new-score reviewer-weight) u100))

;; Helper function to determine certification level
(define-private (determine-certification-level (score uint))
  (if (>= score u95)
      u3 ;; Gold
      (if (>= score u85)
          u2 ;; Silver
          (if (>= score u75)
              u1 ;; Bronze
              u0)))) ;; None

;; Function to update provider reputation based on dataset performance
(define-public (update-provider-reputation (provider principal) (dataset-id (string-ascii 64)) (performance-score uint))
  (let ((current-reputation (map-get? provider-reputation { provider: provider }))
        (dataset-metrics (map-get? dataset-quality-metrics { dataset-id: dataset-id })))
    
    (asserts! (is-some dataset-metrics) (err ERR-DATASET-NOT-FOUND))
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-OWNER-ONLY))
    
    (let ((reputation-data (default-to 
                            { total-datasets: u0, successful-datasets: u0, total-stake-slashed: u0, 
                              reputation-score: u100, last-update: u0, performance-history: (list) }
                            current-reputation))
          (is-successful (>= performance-score (var-get quality-threshold)))
          (new-total (+ (get total-datasets reputation-data) u1))
          (new-successful (+ (get successful-datasets reputation-data) (if is-successful u1 u0)))
          (new-score (/ (* new-successful u1000) new-total)) ;; Calculate percentage * 10
          (new-history-entry { dataset-id: dataset-id, score: performance-score, timestamp: stacks-block-height })
          (updated-history (unwrap! (as-max-len? 
                                    (append (get performance-history reputation-data) new-history-entry) 
                                    u20) (err ERR-INVALID-SCORES))))
      
      (map-set provider-reputation
        { provider: provider }
        (merge reputation-data {
          total-datasets: new-total,
          successful-datasets: new-successful,
          reputation-score: new-score,
          last-update: stacks-block-height,
          performance-history: updated-history
        }))
      
      (ok true))))

;; Enhanced slashing function with reputation impact
(define-public (slash-stake (dataset-id (string-ascii 64)) (provider principal) (slash-percentage uint) (reason (string-ascii 128)))
  (let ((dataset-entry (map-get? dataset-stakes { provider: provider, dataset-id: dataset-id }))
        (is-authorized (default-to false (map-get? authorized-slashers tx-sender)))
        (provider-rep (map-get? provider-reputation { provider: provider })))
    
    (asserts! is-authorized (err ERR-SLASHER-ONLY))
    (asserts! (is-some dataset-entry) (err ERR-STAKE-NOT-FOUND))
    (asserts! (<= slash-percentage u100) (err ERR-INVALID-SLASH-PERCENTAGE))
    
    (let ((stake-data (unwrap! dataset-entry (err ERR-STAKE-NOT-FOUND)))
          (stake-amount (get stake-amount stake-data))
          (slash-amount (/ (* stake-amount slash-percentage) u100)))
      
      ;; Transfer slashed amount to community pool
      (try! (as-contract (stx-transfer? slash-amount tx-sender (var-get contract-owner))))
      
      ;; Update stake
      (map-set dataset-stakes 
        { provider: provider, dataset-id: dataset-id } 
        (merge stake-data { stake-amount: (- stake-amount slash-amount) }))
      
      ;; Update provider reputation if exists
      (match provider-rep
        rep-data (map-set provider-reputation
                   { provider: provider }
                   (merge rep-data {
                     total-stake-slashed: (+ (get total-stake-slashed rep-data) slash-amount),
                     reputation-score: (if (> (get reputation-score rep-data) u50)
                                           (- (get reputation-score rep-data) u50)
                                           u0)
                   }))
        true) ;; Do nothing if no reputation record exists
      
      ;; Print event (note: print returns (ok true) so we handle it properly)
      (print { event: "stake-slashed", provider: provider, dataset-id: dataset-id, amount: slash-amount, reason: reason })
      (ok true))))

;; Function to unlock stake after lock period
(define-public (unlock-stake (dataset-id (string-ascii 64)))
  (let ((dataset-entry (map-get? dataset-stakes { provider: tx-sender, dataset-id: dataset-id })))
    (asserts! (is-some dataset-entry) (err ERR-STAKE-NOT-FOUND))
    
    (let ((stake-data (unwrap! dataset-entry (err ERR-STAKE-NOT-FOUND))))
      (asserts! (get is-locked stake-data) (err ERR-STAKE-LOCKED))
      (asserts! (>= stacks-block-height (get unlock-time stake-data)) (err ERR-STAKE-LOCKED))
      
      (map-set dataset-stakes 
        { provider: tx-sender, dataset-id: dataset-id } 
        (merge stake-data { is-locked: false }))
      
      (ok true))))

;; Enhanced release function with reputation bonus
(define-public (release-stake (dataset-id (string-ascii 64)) (performance-score uint))
  (let ((dataset-entry (map-get? dataset-stakes { provider: tx-sender, dataset-id: dataset-id }))
        (provider-rep (default-to u100 (get reputation-score (map-get? provider-reputation { provider: tx-sender })))))
    
    (asserts! (is-some dataset-entry) (err ERR-STAKE-NOT-FOUND))
    
    (let ((stake-data (unwrap! dataset-entry (err ERR-STAKE-NOT-FOUND)))
          (stake-amount (get stake-amount stake-data))
          (reputation-bonus (/ provider-rep u100)) ;; 1-10% bonus based on reputation
          (base-release (/ (* stake-amount performance-score) u100))
          (bonus-amount (/ (* base-release reputation-bonus) u100))
          (total-release (+ base-release bonus-amount)))
      
      (asserts! (not (get is-locked stake-data)) (err ERR-STAKE-LOCKED))
      
      ;; Transfer released amount back to provider
      (try! (as-contract (stx-transfer? total-release tx-sender tx-sender)))
      
      ;; Update stake amount
      (map-set dataset-stakes 
        { provider: tx-sender, dataset-id: dataset-id } 
        (merge stake-data { stake-amount: (- stake-amount total-release) }))
      
      ;; Update reputation
      (try! (update-provider-reputation tx-sender dataset-id performance-score))
      
      (ok true))))

;; Read-only functions for querying enhanced data

(define-read-only (get-provider-reputation (provider principal))
  (map-get? provider-reputation { provider: provider }))

(define-read-only (get-dataset-quality-metrics (dataset-id (string-ascii 64)))
  (map-get? dataset-quality-metrics { dataset-id: dataset-id }))

(define-read-only (get-category-requirements (category uint))
  (map-get? category-requirements { category: category }))

(define-read-only (get-dataset-stake-info (provider principal) (dataset-id (string-ascii 64)))
  (map-get? dataset-stakes { provider: provider, dataset-id: dataset-id }))

(define-read-only (is-stake-unlocked (provider principal) (dataset-id (string-ascii 64)))
  (let ((stake-info (map-get? dataset-stakes { provider: provider, dataset-id: dataset-id })))
    (match stake-info
      stake-data (or (not (get is-locked stake-data)) 
                     (>= stacks-block-height (get unlock-time stake-data)))
      false)))

(define-read-only (calculate-effective-stake (stake-amount uint) (lock-period uint))
  (let ((multiplier (get-lock-multiplier lock-period)))
    (/ (* stake-amount multiplier) u10000)))

;; Function to get provider tier based on reputation
(define-read-only (get-provider-tier (provider principal))
  (let ((reputation (default-to u0 (get reputation-score (map-get? provider-reputation { provider: provider })))))
    (if (>= reputation u900)
        "Diamond"
        (if (>= reputation u750)
            "Platinum"
            (if (>= reputation u600)
                "Gold"
                (if (>= reputation u400)
                    "Silver"
                    "Bronze"))))))

;; Function to check if provider is authorized reviewer
(define-read-only (is-authorized-reviewer (reviewer principal))
  (default-to false (map-get? authorized-reviewers reviewer)))

;; Function to check if provider is authorized slasher
(define-read-only (is-authorized-slasher (slasher principal))
  (default-to false (map-get? authorized-slashers slasher)))

;; Function to get contract configuration
(define-read-only (get-contract-config)
  {
    minimum-stake: (var-get minimum-stake),
    contract-owner: (var-get contract-owner),
    reputation-decay-rate: (var-get reputation-decay-rate),
    quality-threshold: (var-get quality-threshold)
  })
