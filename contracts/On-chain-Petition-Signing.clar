;; On-chain Petition Signing Contract with Analytics
;; A comprehensive petition system with built-in analytics capabilities

;; Error constants
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_PETITION_NOT_FOUND (err u101))
(define-constant ERR_PETITION_INACTIVE (err u102))
(define-constant ERR_ALREADY_SIGNED (err u103))
(define-constant ERR_INVALID_THRESHOLD (err u104))
(define-constant ERR_PETITION_EXPIRED (err u105))
(define-constant ERR_INVALID_DURATION (err u106))
(define-constant ERR_EMPTY_TITLE (err u107))
(define-constant ERR_EMPTY_DESCRIPTION (err u108))
(define-constant ERR_CANNOT_SIGN_OWN_PETITION (err u109))

;; Contract owner
(define-constant CONTRACT_OWNER tx-sender)

;; Data variables
(define-data-var next-petition-id uint u1)
(define-data-var total-petitions uint u0)
(define-data-var total-signatures uint u0)
(define-data-var analytics-enabled bool true)

;; Petition data structure
(define-map petitions
    { petition-id: uint }
    {
        title: (string-ascii 100),
        description: (string-ascii 500),
        creator: principal,
        created-at: uint,
        expires-at: uint,
        signature-threshold: uint,
        current-signatures: uint,
        is-active: bool,
        is-successful: bool,
        category: (string-ascii 50)
    }
)

;; Signature tracking
(define-map signatures
    {
        petition-id: uint,
        signer: principal,
    }
    { signed-at: uint }
)

;; User activity tracking for analytics
(define-map user-analytics
    { user: principal }
    {
        petitions-created: uint,
        petitions-signed: uint,
        first-activity: uint,
        last-activity: uint
    }
)

;; Daily analytics aggregation
(define-map daily-stats
    { day: uint }
    {
        petitions-created: uint,
        signatures-made: uint,
        unique-users: uint
    }
)

;; Petition performance metrics
(define-map petition-performance
    { petition-id: uint }
    {
        daily-rate: uint,
        time-to-first: uint,
        completion-rate: uint
    }
)

;; === CORE PETITION FUNCTIONS ===

;; Create a new petition
(define-public (create-petition
        (title (string-ascii 100))
        (description (string-ascii 500))
        (signature-threshold uint)
        (duration-blocks uint)
        (category (string-ascii 50))
    )
    (let (
            (petition-id (var-get next-petition-id))
            (current-time (unwrap! (get-stacks-block-info? time (- stacks-block-height u1))
                ERR_PETITION_NOT_FOUND
            ))
            (expires-at (+ current-time (* duration-blocks u600)))
        )
        ;; Validation
        (asserts! (> (len title) u0) ERR_EMPTY_TITLE)
        (asserts! (> (len description) u0) ERR_EMPTY_DESCRIPTION)
        (asserts! (> signature-threshold u0) ERR_INVALID_THRESHOLD)
        (asserts! (> duration-blocks u0) ERR_INVALID_DURATION)

        ;; Create petition
        (map-set petitions { petition-id: petition-id } {
            title: title,
            description: description,
            creator: tx-sender,
            created-at: current-time,
            expires-at: expires-at,
            signature-threshold: signature-threshold,
            current-signatures: u0,
            is-active: true,
            is-successful: false,
            category: category
        })

        ;; Update counters
        (var-set next-petition-id (+ petition-id u1))
        (var-set total-petitions (+ (var-get total-petitions) u1))

        ;; Update analytics
        (update-user-analytics tx-sender true false)
        (update-daily-stats current-time true false)
        (init-petition-performance petition-id)

        (ok petition-id)
    )
)

;; Sign a petition
(define-public (sign-petition (petition-id uint))
    (let (
            (petition-data (unwrap! (get-petition petition-id) ERR_PETITION_NOT_FOUND))
            (current-time (unwrap! (get-stacks-block-info? time (- stacks-block-height u1))
                ERR_PETITION_NOT_FOUND
            ))
        )
        ;; Validation
        (asserts! (get is-active petition-data) ERR_PETITION_INACTIVE)
        (asserts! (not (is-petition-expired petition-id)) ERR_PETITION_EXPIRED)
        (asserts! (not (has-signed petition-id tx-sender)) ERR_ALREADY_SIGNED)
        (asserts! (not (is-eq tx-sender (get creator petition-data)))
            ERR_CANNOT_SIGN_OWN_PETITION
        )

        ;; Record signature
        (map-set signatures {
            petition-id: petition-id,
            signer: tx-sender,
        } { signed-at: current-time })

        ;; Update petition signature count
        (let ((new-signature-count (+ (get current-signatures petition-data) u1)))
            (map-set petitions { petition-id: petition-id }
                (merge petition-data { current-signatures: new-signature-count })
            )

            ;; Check if petition reached threshold
            (if (>= new-signature-count (get signature-threshold petition-data))
                (map-set petitions { petition-id: petition-id }
                    (merge petition-data { 
                        current-signatures: new-signature-count,
                        is-successful: true 
                    })
                )
                true
            )
        )

        ;; Update global counters
        (var-set total-signatures (+ (var-get total-signatures) u1))

        ;; Update analytics
        (update-user-analytics tx-sender false true)
        (update-daily-stats current-time false true)
        (update-petition-performance petition-id current-time)

        (ok true)
    )
)

;; Deactivate petition (creator only)
(define-public (deactivate-petition (petition-id uint))
    (let ((petition-data (unwrap! (get-petition petition-id) ERR_PETITION_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get creator petition-data)) ERR_NOT_AUTHORIZED)
        (asserts! (get is-active petition-data) ERR_PETITION_INACTIVE)

        (map-set petitions { petition-id: petition-id }
            (merge petition-data { is-active: false })
        )
        (ok true)
    )
)

;; Reactivate petition (creator only)
(define-public (reactivate-petition (petition-id uint))
    (let ((petition-data (unwrap! (get-petition petition-id) ERR_PETITION_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get creator petition-data)) ERR_NOT_AUTHORIZED)
        (asserts! (not (get is-active petition-data)) ERR_PETITION_INACTIVE)
        (asserts! (not (is-petition-expired petition-id)) ERR_PETITION_EXPIRED)

        (map-set petitions { petition-id: petition-id }
            (merge petition-data { is-active: true })
        )
        (ok true)
    )
)

;; === READ-ONLY FUNCTIONS ===

;; Get petition details
(define-read-only (get-petition (petition-id uint))
    (map-get? petitions { petition-id: petition-id })
)

;; Check if user has signed petition
(define-read-only (has-signed (petition-id uint) (user principal))
    (is-some (map-get? signatures {
        petition-id: petition-id,
        signer: user,
    }))
)

;; Check if petition is expired
(define-read-only (is-petition-expired (petition-id uint))
    (match (get-petition petition-id)
        petition-data (match (get-stacks-block-info? time (- stacks-block-height u1))
            current-time (> current-time (get expires-at petition-data))
            false
        )
        false
    )
)

;; Check if petition is successful
(define-read-only (is-petition-successful (petition-id uint))
    (match (get-petition petition-id)
        petition-data (>= (get current-signatures petition-data)
            (get signature-threshold petition-data)
        )
        false
    )
)

;; Get petition status
(define-read-only (get-petition-status (petition-id uint))
    (match (get-petition petition-id)
        petition-data (if (get is-successful petition-data)
            "successful"
            (if (is-petition-expired petition-id)
                "expired"
                (if (get is-active petition-data)
                    "active"
                    "inactive"
                )
            )
        )
        "not-found"
    )
)

;; Get petition progress
(define-read-only (get-petition-progress (petition-id uint))
    (match (get-petition petition-id)
        petition-data (ok {
            current: (get current-signatures petition-data),
            threshold: (get signature-threshold petition-data),
            percentage: (/ (* (get current-signatures petition-data) u100)
                (get signature-threshold petition-data)
            ),
        })
        ERR_PETITION_NOT_FOUND
    )
)

;; === ANALYTICS FUNCTIONS (NEW INDEPENDENT FEATURE) ===

;; Get user activity statistics
(define-read-only (get-user-analytics (user principal))
    (default-to {
        petitions-created: u0,
        petitions-signed: u0,
        first-activity: u0,
        last-activity: u0
    } (map-get? user-analytics { user: user }))
)

;; Get daily statistics for a specific day
(define-read-only (get-daily-stats (day uint))
    (default-to {
        petitions-created: u0,
        signatures-made: u0,
        unique-users: u0
    } (map-get? daily-stats { day: day }))
)

;; Get petition performance metrics
(define-read-only (get-petition-performance (petition-id uint))
    (map-get? petition-performance { petition-id: petition-id })
)

;; Get platform-wide analytics summary
(define-read-only (get-platform-analytics)
    (ok {
        total-petitions: (var-get total-petitions),
        total-signatures: (var-get total-signatures),
        average-signatures-per-petition: (if (> (var-get total-petitions) u0)
            (/ (var-get total-signatures) (var-get total-petitions))
            u0
        ),
        analytics-enabled: (var-get analytics-enabled)
    })
)

;; Get leaderboard of most active petition creators
(define-read-only (get-creator-leaderboard (creator principal))
    (let ((user-data (get-user-analytics creator)))
        {
            creator: creator,
            total-petitions: (get petitions-created user-data),
            total-signatures-received: u0,
            success-rate: u0
        }
    )
)

;; Get leaderboard of most active petition signers
(define-read-only (get-signer-leaderboard (signer principal))
    (let ((user-data (get-user-analytics signer)))
        {
            signer: signer,
            total-signatures: (get petitions-signed user-data),
            first-signature: (get first-activity user-data),
            last-signature: (get last-activity user-data)
        }
    )
)

;; === PRIVATE HELPER FUNCTIONS ===

;; Update user analytics
(define-private (update-user-analytics (user principal) (created-petition bool) (signed-petition bool))
    (let (
            (current-data (get-user-analytics user))
            (current-time (unwrap! (get-stacks-block-info? time (- stacks-block-height u1)) 
                u0))
        )
        (map-set user-analytics { user: user } {
            petitions-created: (+ (get petitions-created current-data)
                (if created-petition u1 u0)),
            petitions-signed: (+ (get petitions-signed current-data)
                (if signed-petition u1 u0)),
            first-activity: (if (is-eq (get first-activity current-data) u0)
                current-time
                (get first-activity current-data)),
            last-activity: current-time
        })
        true
    )
)

;; Update daily statistics
(define-private (update-daily-stats (timestamp uint) (petition-created bool) (signature-made bool))
    (let (
            (day (/ timestamp u86400))
            (current-daily (get-daily-stats day))
        )
        (map-set daily-stats { day: day } {
            petitions-created: (+ (get petitions-created current-daily)
                (if petition-created u1 u0)),
            signatures-made: (+ (get signatures-made current-daily)
                (if signature-made u1 u0)),
            unique-users: (get unique-users current-daily)
        })
        true
    )
)

;; Initialize petition performance tracking
(define-private (init-petition-performance (petition-id uint))
    (map-set petition-performance { petition-id: petition-id } {
        daily-rate: u0,
        time-to-first: u0,
        completion-rate: u0
    })
    true
)

;; Update petition performance metrics
(define-private (update-petition-performance (petition-id uint) (signature-time uint))
    (match (get-petition-performance petition-id)
        current-metrics (begin
            (match (get-petition petition-id)
                petition-data (if (is-eq (get current-signatures petition-data) u1)
                    (map-set petition-performance { petition-id: petition-id }
                        (merge current-metrics { 
                            time-to-first: (- signature-time (get created-at petition-data))
                        })
                    )
                    true
                )
                true
            )
        )
        true
    )
)

;; === ADMIN FUNCTIONS ===

;; Toggle analytics collection (contract owner only)
(define-public (toggle-analytics)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (var-set analytics-enabled (not (var-get analytics-enabled)))
        (ok (var-get analytics-enabled))
    )
)
