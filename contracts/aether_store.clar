;; Constants
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_INSUFFICIENT_FUNDS (err u402))
(define-constant ERR_OUT_OF_STOCK (err u405))

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
    timestamp: uint
  }
)

(define-map store-stats
  { seller: principal }
  {
    total-sales: uint,
    avg-rating: uint,
    review-count: uint
  }
)

;; Data variables
(define-data-var next-product-id uint u1)

;; Public functions
(define-public (list-product 
  (name (string-ascii 100))
  (price uint)
  (quantity uint)
  (description (string-ascii 500))
  (seller principal)
)
  (let ((product-id (var-get next-product-id)))
    (if (is-eq tx-sender seller)
      (begin
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
      ERR_UNAUTHORIZED
    )
  )
)

(define-public (purchase-product (product-id uint) (buyer principal))
  (let (
    (product (unwrap! (map-get? products { product-id: product-id }) ERR_NOT_FOUND))
    (seller (get seller product))
    (price (get price product))
    (quantity (get quantity product))
  )
    (if (> quantity u0)
      (if (is-eq tx-sender buyer)
        (begin
          (try! (stx-transfer? price buyer seller))
          (map-set products
            { product-id: product-id }
            (merge product { quantity: (- quantity u1) })
          )
          (update-store-stats seller price)
          (ok true)
        )
        ERR_UNAUTHORIZED
      )
      ERR_OUT_OF_STOCK
    )
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
  )
    (map-set reviews
      { product-id: product-id, reviewer: tx-sender }
      {
        rating: rating,
        comment: comment,
        timestamp: block-height
      }
    )
    (update-store-rating seller rating)
    (ok true)
  )
)

;; Private functions
(define-private (update-store-stats (seller principal) (sale-amount uint))
  (let ((stats (default-to
    { total-sales: u0, avg-rating: u0, review-count: u0 }
    (map-get? store-stats { seller: seller }))))
    (map-set store-stats
      { seller: seller }
      (merge stats { total-sales: (+ (get total-sales stats) sale-amount) })
    )
  )
)

(define-private (update-store-rating (seller principal) (new-rating uint))
  (let ((stats (default-to
    { total-sales: u0, avg-rating: u0, review-count: u0 }
    (map-get? store-stats { seller: seller }))))
    (let (
      (current-count (get review-count stats))
      (current-avg (get avg-rating stats))
      (new-count (+ current-count u1))
    )
      (map-set store-stats
        { seller: seller }
        (merge stats {
          avg-rating: (/ (+ (* current-avg current-count) new-rating) new-count),
          review-count: new-count
        })
      )
    )
  )
)

;; Read only functions
(define-read-only (get-product (product-id uint))
  (map-get? products { product-id: product-id })
)

(define-read-only (get-store-stats (seller principal))
  (map-get? store-stats { seller: seller })
)

(define-read-only (get-review (product-id uint) (reviewer principal))
  (map-get? reviews { product-id: product-id, reviewer: reviewer })
)
