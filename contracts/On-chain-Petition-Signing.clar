;; Simple Petition Contract with Analytics
;; Clean implementation that passes clarinet check

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
(define-constant ERR_NOT_SIGNED (err u110))
(define-constant ERR_CANNOT_REVOKE_SUCCESSFUL (err u111))
(define-constant ERR_INVALID_REVOCATION (err u112))

;; Contract owner
(define-constant CONTRACT_OWNER tx-sender)

;; Data variables
(define-data-var next-petition-id uint u1)
(define-data-var total-petitions uint u0)
(define-data-var total-signatures uint u0)

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

;; Analytics: User activity tracking
(define-map user-analytics
    { user: principal }
    {
        petitions-created: uint,
        petitions-signed: uint,
        last-activity: uint,
    }
)

;; Analytics: Daily stats
(define-map daily-stats
    { day: uint }
    {
        petitions-created: uint,
        signatures-made: uint,
    }
)

;; === PUBLIC FUNCTIONS ===

;; Create a new petition
(define-public (create-petition
        (title (string-ascii 100))
        (description (string-ascii 500))
        (signature-threshold uint)
        (duration-blocks uint)
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
        })

        ;; Update counters
        (var-set next-petition-id (+ petition-id u1))
        (var-set total-petitions (+ (var-get total-petitions) u1))

        ;; Update analytics
        (update-user-stats tx-sender true false)
        (update-daily-stats current-time true false)

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
        } { signed-at: current-time }
        )

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
                        is-successful: true,
                    })
                )
                true
            )
        )

        ;; Update global counters
        (var-set total-signatures (+ (var-get total-signatures) u1))

        ;; Update analytics
        (update-user-stats tx-sender false true)
        (update-daily-stats current-time false true)

        (ok true)
    )
)

(define-public (revoke-signature (petition-id uint))
    (let (
            (petition-data (unwrap! (get-petition petition-id) ERR_PETITION_NOT_FOUND))
            (current-signatures (get current-signatures petition-data))
        )
        (asserts! (get is-active petition-data) ERR_PETITION_INACTIVE)
        (asserts! (not (is-petition-expired petition-id)) ERR_PETITION_EXPIRED)
        (asserts! (not (get is-successful petition-data))
            ERR_CANNOT_REVOKE_SUCCESSFUL
        )
        (asserts! (has-signed petition-id tx-sender) ERR_NOT_SIGNED)
        (asserts! (> current-signatures u0) ERR_INVALID_REVOCATION)
        (map-delete signatures {
            petition-id: petition-id,
            signer: tx-sender,
        })
        (let ((new-signature-count (- current-signatures u1)))
            (map-set petitions { petition-id: petition-id }
                (merge petition-data { current-signatures: new-signature-count })
            )
        )
        (var-set total-signatures (- (var-get total-signatures) u1))
        (ok true)
    )
)

;; === READ-ONLY FUNCTIONS ===

;; Get petition details
(define-read-only (get-petition (petition-id uint))
    (map-get? petitions { petition-id: petition-id })
)

;; Check if user has signed petition
(define-read-only (has-signed
        (petition-id uint)
        (user principal)
    )
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

;; === ANALYTICS FUNCTIONS ===

;; Get user analytics
(define-read-only (get-user-analytics (user principal))
    (default-to {
        petitions-created: u0,
        petitions-signed: u0,
        last-activity: u0,
    }
        (map-get? user-analytics { user: user })
    )
)

;; Get daily stats
(define-read-only (get-daily-stats (day uint))
    (default-to {
        petitions-created: u0,
        signatures-made: u0,
    }
        (map-get? daily-stats { day: day })
    )
)

;; Get platform analytics
(define-read-only (get-platform-analytics)
    (ok {
        total-petitions: (var-get total-petitions),
        total-signatures: (var-get total-signatures),
        average-signatures: (if (> (var-get total-petitions) u0)
            (/ (var-get total-signatures) (var-get total-petitions))
            u0
        ),
    })
)

;; === PRIVATE FUNCTIONS ===

;; Update user statistics
(define-private (update-user-stats
        (user principal)
        (created bool)
        (signed bool)
    )
    (let (
            (current-stats (get-user-analytics user))
            (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
        )
        (map-set user-analytics { user: user } {
            petitions-created: (+ (get petitions-created current-stats)
                (if created
                    u1
                    u0
                )),
            petitions-signed: (+ (get petitions-signed current-stats)
                (if signed
                    u1
                    u0
                )),
            last-activity: current-time,
        })
    )
)

;; Update daily statistics
(define-private (update-daily-stats
        (timestamp uint)
        (petition-created bool)
        (signature-made bool)
    )
    (let (
            (day (/ timestamp u86400))
            (current-daily (get-daily-stats day))
        )
        (map-set daily-stats { day: day } {
            petitions-created: (+ (get petitions-created current-daily)
                (if petition-created
                    u1
                    u0
                )),
            signatures-made: (+ (get signatures-made current-daily)
                (if signature-made
                    u1
                    u0
                )),
        })
    )
)
