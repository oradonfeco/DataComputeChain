;; compute-resource.clar
;; Implements compute resource tokenization as NFTs

(define-non-fungible-token compute-resource-nft (string-ascii 64))

(define-map compute-resources 
  { resource-id: (string-ascii 64) }
  { 
    owner: principal,
    specs: {
      gpu-type: (string-ascii 64),
      memory: uint,
      compute-power: uint
    },
    availability: {
      start-time: uint,
      end-time: uint
    },
    price-per-hour: uint,
    is-fractional: bool,
    fractions-available: uint,
    fractions-total: uint
  }
)

(define-map resource-bookings
  { resource-id: (string-ascii 64), time-slot: uint }
  { booker: principal, duration: uint, paid-amount: uint }
)

;; Function to register a new compute resource
(define-public (register-compute-resource 
                (resource-id (string-ascii 64)) 
                (gpu-type (string-ascii 64)) 
                (memory uint) 
                (compute-power uint)
                (price-per-hour uint)
                (is-fractional bool)
                (fractions-total uint))
  (let ((resource-exists (is-some (map-get? compute-resources { resource-id: resource-id }))))
    (if resource-exists
        (err u1) ;; Resource ID already exists
        (begin
          (try! (nft-mint? compute-resource-nft resource-id tx-sender))
          (map-set compute-resources
            { resource-id: resource-id }
            {
              owner: tx-sender,
              specs: {
                gpu-type: gpu-type,
                memory: memory,
                compute-power: compute-power
              },
              availability: {
                start-time: u0,
                end-time: u0
              },
              price-per-hour: price-per-hour,
              is-fractional: is-fractional,
              fractions-available: (if is-fractional fractions-total u1),
              fractions-total: (if is-fractional fractions-total u1)
            })
          (ok true)))))

;; Function to update resource availability
(define-public (update-availability (resource-id (string-ascii 64)) (start-time uint) (end-time uint))
  (let ((resource (map-get? compute-resources { resource-id: resource-id })))
    (if (and (is-some resource) (is-eq tx-sender (get owner (unwrap-panic resource))))
        (begin
          (map-set compute-resources
            { resource-id: resource-id }
            (merge (unwrap-panic resource)
                  { availability: { start-time: start-time, end-time: end-time } }))
          (ok true))
        (err u2))))

;; Function to update resource pricing
(define-public (update-pricing (resource-id (string-ascii 64)) (new-price-per-hour uint))
  (let ((resource (map-get? compute-resources { resource-id: resource-id })))
    (if (and (is-some resource) (is-eq tx-sender (get owner (unwrap-panic resource))))
        (begin
          (map-set compute-resources
            { resource-id: resource-id }
            (merge (unwrap-panic resource) { price-per-hour: new-price-per-hour }))
          (ok true))
        (err u3))))

;; Function to book compute time
(define-public (book-compute-time (resource-id (string-ascii 64)) (time-slot uint) (duration uint))
  (let ((resource (map-get? compute-resources { resource-id: resource-id }))
        (booking-exists (is-some (map-get? resource-bookings { resource-id: resource-id, time-slot: time-slot }))))
    (if (and (is-some resource) (not booking-exists))
        (let ((resource-data (unwrap-panic resource))
              (total-cost (* (get price-per-hour resource-data) duration)))
          (if (and (>= (get start-time (get availability resource-data)) time-slot)
                  (<= (+ time-slot duration) (get end-time (get availability resource-data)))
                  (> (get fractions-available resource-data) u0))
              (begin
                (try! (stx-transfer? total-cost tx-sender (get owner resource-data)))
                (map-set resource-bookings
                  { resource-id: resource-id, time-slot: time-slot }
                  { booker: tx-sender, duration: duration, paid-amount: total-cost })
                (map-set compute-resources
                  { resource-id: resource-id }
                  (merge resource-data 
                        { fractions-available: (- (get fractions-available resource-data) u1) }))
                (ok true))
              (err u4)))
        (err u5))))

;; Function to create fractional ownership tokens
(define-public (create-fractional-tokens (resource-id (string-ascii 64)) (fractions uint))
  (let ((resource (map-get? compute-resources { resource-id: resource-id })))
    (if (and (is-some resource) 
             (is-eq tx-sender (get owner (unwrap-panic resource)))
             (not (get is-fractional (unwrap-panic resource))))
        (begin
          (map-set compute-resources
            { resource-id: resource-id }
            (merge (unwrap-panic resource) 
                  { 
                    is-fractional: true,
                    fractions-available: fractions,
                    fractions-total: fractions
                  }))
          (ok true))
        (err u6))))

;; Function to transfer fractional ownership
(define-public (transfer-fraction (resource-id (string-ascii 64)) (recipient principal) (fraction-count uint))
  (let ((resource (map-get? compute-resources { resource-id: resource-id })))
    (if (and (is-some resource)
             (is-eq tx-sender (get owner (unwrap-panic resource)))
             (get is-fractional (unwrap-panic resource))
             (<= fraction-count (get fractions-available (unwrap-panic resource))))
        (begin
          ;; In a real implementation, we would mint new NFTs for the fractions
          ;; For simplicity, we're just updating the resource record
          (print { event: "fraction-transferred", resource-id: resource-id, recipient: recipient, count: fraction-count })
          (ok true))
        (err u7))))