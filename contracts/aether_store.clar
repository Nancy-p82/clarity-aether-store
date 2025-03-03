;; Constants
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_INSUFFICIENT_FUNDS (err u402))
(define-constant ERR_OUT_OF_STOCK (err u405))
(define-constant ERR_INVALID_INPUT (err u400))
(define-constant ERR_DUPLICATE_REVIEW (err u409))

;; Data structures
(define-map products 
  { product-id: uint }
  {
    name: (string-ascii 100),
    price: uint,
    quantity: uint,
    description: (string-ascii 500),
    seller: principal,
    active: bool
  }
)

(define-map reviews
  { product-id: uint, reviewer: principal }
  {
    rating: uint,
    comment: (string-ascii 500),
    timestamp: uint,
    last-modified: uint
  }
)

(define-map store-stats
  { seller: principal }
  {
    total-sales: uint,
    total-rating: uint,
    review-count: uint
  }
)

;; Data variables
(define-data-var next-product-id uint u1)

;; Private functions
(define-private (validate-price (price uint))
  (> price u0)
)

(define-private (validate-quantity (quantity uint))
  (>= quantity u0)
)

(define-private (validate-rating (rating uint))
  (and (>= rating u1) (<= rating u5))
)

;; Public functions
(define-public (list-product 
  (name (string-ascii 100))
  (price uint)
  (quantity uint)
  (description (string-ascii 500))
  (seller principal)
)
  (let ((product-id (var-get next-product-id)))
    (asserts! (is-eq tx-sender seller) ERR_UNAUTHORIZED)
    (asserts! (validate-price price) ERR_INVALID_INPUT)
    (asserts! (validate-quantity quantity) ERR_INVALID_INPUT)
    
    (map-set products
      { product-id: product-id }
      {
        name: name,
        price: price,
        quantity: quantity,
        description: description,
        seller: seller,
        active: true
      }
    )
    (var-set next-product-id (+ product-id u1))
    (ok product-id)
  )
)

(define-public (purchase-product (product-id uint) (buyer principal))
  (let (
    (product (unwrap! (map-get? products { product-id: product-id }) ERR_NOT_FOUND))
    (seller (get seller product))
    (price (get price product))
    (quantity (get quantity product))
    (active (get active product))
  )
    (asserts! active ERR_NOT_FOUND)
    (asserts! (> quantity u0) ERR_OUT_OF_STOCK)
    (asserts! (is-eq tx-sender buyer) ERR_UNAUTHORIZED)
    
    (try! (stx-transfer? price buyer seller))
    (map-set products
      { product-id: product-id }
      (merge product { quantity: (- quantity u1) })
    )
    (update-store-stats seller price)
    (ok true)
  )
)

(define-public (leave-review 
  (product-id uint)
  (rating uint)
  (comment (string-ascii 500))
)
  (let (
    (product (unwrap! (map-get? products { product-id: product-id }) ERR_NOT_FOUND))
    (seller (get seller product))
    (existing-review (map-get? reviews { product-id: product-id, reviewer: tx-sender }))
  )
    (asserts! (validate-rating rating) ERR_INVALID_INPUT)
    (asserts! (is-none existing-review) ERR_DUPLICATE_REVIEW)
    
    (map-set reviews
      { product-id: product-id, reviewer: tx-sender }
      {
        rating: rating,
        comment: comment,
        timestamp: block-height,
        last-modified: block-height
      }
    )
    (update-store-rating seller rating)
    (ok true)
  )
)

;; Store management functions
(define-public (deactivate-product (product-id uint))
  (let ((product (unwrap! (map-get? products { product-id: product-id }) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get seller product)) ERR_UNAUTHORIZED)
    (map-set products
      { product-id: product-id }
      (merge product { active: false })
    )
    (ok true)
  )
)

;; Private helper functions
(define-private (update-store-stats (seller principal) (sale-amount uint))
  (let ((stats (default-to
    { total-sales: u0, total-rating: u0, review-count: u0 }
    (map-get? store-stats { seller: seller }))))
    (map-set store-stats
      { seller: seller }
      (merge stats { total-sales: (+ (get total-sales stats) sale-amount) })
    )
  )
)

(define-private (update-store-rating (seller principal) (new-rating uint))
  (let ((stats (default-to
    { total-sales: u0, total-rating: u0, review-count: u0 }
    (map-get? store-stats { seller: seller }))))
    (map-set store-stats
      { seller: seller }
      (merge stats {
        total-rating: (+ (get total-rating stats) new-rating),
        review-count: (+ (get review-count stats) u1)
      })
    )
  )
)

;; Read only functions
(define-read-only (get-product (product-id uint))
  (map-get? products { product-id: product-id })
)

(define-read-only (get-store-stats (seller principal))
  (let ((stats (unwrap! (map-get? store-stats { seller: seller }) (tuple (total-sales u0) (total-rating u0) (review-count u0)))))
    (if (is-eq (get review-count stats) u0)
      stats
      (merge stats { avg-rating: (/ (get total-rating stats) (get review-count stats)) })
    )
  )
)

(define-read-only (get-review (product-id uint) (reviewer principal))
  (map-get? reviews { product-id: product-id, reviewer: reviewer })
)
