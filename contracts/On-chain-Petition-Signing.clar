(define-constant CONTRACT_OWNER tx-sender)
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

(define-data-var next-petition-id uint u1)
(define-data-var total-petitions uint u0)

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

(define-map signatures
    {
        petition-id: uint,
        signer: principal,
    }
    { signed-at: uint }
)

(define-map petition-signers
    { petition-id: uint }
    { signers: (list 1000 principal) }
)

(define-map user-signatures
    { user: principal }
    { petition-ids: (list 100 uint) }
)

(define-read-only (get-petition (petition-id uint))
    (map-get? petitions { petition-id: petition-id })
)

(define-read-only (get-petition-signers (petition-id uint))
    (default-to { signers: (list) }
        (map-get? petition-signers { petition-id: petition-id })
    )
)

(define-read-only (has-signed
        (petition-id uint)
        (user principal)
    )
    (is-some (map-get? signatures {
        petition-id: petition-id,
        signer: user,
    }))
)

(define-read-only (get-user-signatures (user principal))
    (default-to { petition-ids: (list) }
        (map-get? user-signatures { user: user })
    )
)

(define-read-only (get-total-petitions)
    (var-get total-petitions)
)

(define-read-only (get-next-petition-id)
    (var-get next-petition-id)
)

(define-read-only (is-petition-expired (petition-id uint))
    (match (get-petition petition-id)
        petition-data (match (get-stacks-block-info? time (- stacks-block-height u1))
            current-time (> current-time (get expires-at petition-data))
            false
        )
        false
    )
)

(define-read-only (is-petition-successful (petition-id uint))
    (match (get-petition petition-id)
        petition-data (>= (get current-signatures petition-data)
            (get signature-threshold petition-data)
        )
        false
    )
)

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

(define-private (update-petition-success (petition-id uint))
    (match (get-petition petition-id)
        petition-data (if (>= (get current-signatures petition-data)
                (get signature-threshold petition-data)
            )
            (map-set petitions { petition-id: petition-id }
                (merge petition-data { is-successful: true })
            )
            true
        )
        false
    )
)

(define-private (add-signer-to-list
        (petition-id uint)
        (new-signer principal)
    )
    (let ((current-signers (get signers (get-petition-signers petition-id))))
        (match (as-max-len? (append current-signers new-signer) u1000)
            updated-list (begin
                (map-set petition-signers { petition-id: petition-id } { signers: updated-list })
                (ok true)
            )
            (err u200)
        )
    )
)

(define-private (add-petition-to-user
        (user principal)
        (petition-id uint)
    )
    (let ((current-petitions (get petition-ids (get-user-signatures user))))
        (match (as-max-len? (append current-petitions petition-id) u100)
            updated-list (begin
                (map-set user-signatures { user: user } { petition-ids: updated-list })
                (ok true)
            )
            (err u201)
        )
    )
)

(define-public (create-petition
        (title (string-ascii 100))
        (description (string-ascii 500))
        (signature-threshold uint)
        (duration-blocks uint)
    )
    (let (
            (petition-id (var-get next-petition-id))
            (current-block-time (unwrap! (get-stacks-block-info? time (- stacks-block-height u1))
                ERR_PETITION_NOT_FOUND
            ))
            (expires-at (+ current-block-time (* duration-blocks u600)))
        )
        (asserts! (> (len title) u0) ERR_EMPTY_TITLE)
        (asserts! (> (len description) u0) ERR_EMPTY_DESCRIPTION)
        (asserts! (> signature-threshold u0) ERR_INVALID_THRESHOLD)
        (asserts! (> duration-blocks u0) ERR_INVALID_DURATION)

        (map-set petitions { petition-id: petition-id } {
            title: title,
            description: description,
            creator: tx-sender,
            created-at: current-block-time,
            expires-at: expires-at,
            signature-threshold: signature-threshold,
            current-signatures: u0,
            is-active: true,
            is-successful: false,
        })

        (map-set petition-signers { petition-id: petition-id } { signers: (list) })

        (var-set next-petition-id (+ petition-id u1))
        (var-set total-petitions (+ (var-get total-petitions) u1))

        (ok petition-id)
    )
)

(define-public (sign-petition (petition-id uint))
    (let ((petition-data (unwrap! (get-petition petition-id) ERR_PETITION_NOT_FOUND)))
        (asserts! (get is-active petition-data) ERR_PETITION_INACTIVE)
        (asserts! (not (is-petition-expired petition-id)) ERR_PETITION_EXPIRED)
        (asserts! (not (has-signed petition-id tx-sender)) ERR_ALREADY_SIGNED)
        (asserts! (not (is-eq tx-sender (get creator petition-data)))
            ERR_CANNOT_SIGN_OWN_PETITION
        )

        (map-set signatures {
            petition-id: petition-id,
            signer: tx-sender,
        } { signed-at: (unwrap! (get-stacks-block-info? time (- stacks-block-height u1))
            ERR_PETITION_NOT_FOUND
        ) }
        )

        (try! (add-signer-to-list petition-id tx-sender))
        (try! (add-petition-to-user tx-sender petition-id))

        (map-set petitions { petition-id: petition-id }
            (merge petition-data { current-signatures: (+ (get current-signatures petition-data) u1) })
        )

        (update-petition-success petition-id)

        (ok true)
    )
)

(define-public (deactivate-petition (petition-id uint))
    (let ((petition-data (unwrap! (get-petition petition-id) ERR_PETITION_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get creator petition-data))
            ERR_NOT_AUTHORIZED
        )
        (asserts! (get is-active petition-data) ERR_PETITION_INACTIVE)

        (map-set petitions { petition-id: petition-id }
            (merge petition-data { is-active: false })
        )

        (ok true)
    )
)

(define-public (reactivate-petition (petition-id uint))
    (let ((petition-data (unwrap! (get-petition petition-id) ERR_PETITION_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get creator petition-data))
            ERR_NOT_AUTHORIZED
        )
        (asserts! (not (get is-active petition-data)) ERR_PETITION_INACTIVE)
        (asserts! (not (is-petition-expired petition-id)) ERR_PETITION_EXPIRED)

        (map-set petitions { petition-id: petition-id }
            (merge petition-data { is-active: true })
        )

        (ok true)
    )
)

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

(define-read-only (get-active-petitions-count)
    (fold count-active-petitions (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) u0)
)

(define-private (count-active-petitions
        (petition-id uint)
        (count uint)
    )
    (match (get-petition petition-id)
        petition-data (if (and (get is-active petition-data) (not (is-petition-expired petition-id)))
            (+ count u1)
            count
        )
        count
    )
)

(define-read-only (get-signature-info
        (petition-id uint)
        (signer principal)
    )
    (map-get? signatures {
        petition-id: petition-id,
        signer: signer,
    })
)
