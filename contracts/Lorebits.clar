;; title: Lorebits
;; version: 1.0.0
;; summary: NFT Story Unlocks - Collect story fragments to unlock epic tales
;; description: A decentralized storytelling platform where users mint story bits and unlock narrative chapters

;; traits
;; (impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; token definitions
(define-non-fungible-token lorebit uint)
(define-fungible-token story-points)

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-listing-not-found (err u102))
(define-constant err-wrong-commission (err u103))
(define-constant err-token-not-found (err u104))
(define-constant err-insufficient-points (err u105))
(define-constant err-story-not-found (err u106))
(define-constant err-chapter-locked (err u107))
(define-constant err-already-unlocked (err u108))

;; data vars
(define-data-var last-token-id uint u0)
(define-data-var total-stories uint u0)
(define-data-var mint-price uint u1000000) ;; 1 STX in microSTX

;; data maps
(define-map token-count principal uint)
(define-map token-uri uint (optional (string-utf8 256)))
(define-map token-metadata uint {
    title: (string-utf8 64),
    story-id: uint,
    chapter: uint,
    rarity: (string-utf8 16),
    creator: principal
})

(define-map stories uint {
    title: (string-utf8 128),
    creator: principal,
    total-chapters: uint,
    unlock-cost: uint,
    created-at: uint
})

(define-map story-chapters {story-id: uint, chapter: uint} {
    content: (string-utf8 1024),
    required-tokens: (list 10 uint),
    unlock-cost: uint
})

(define-map user-unlocks {user: principal, story-id: uint, chapter: uint} bool)
(define-map user-story-points principal uint)

;; public functions

;; Mint a new lorebit NFT
(define-public (mint-lorebit (title (string-utf8 64)) (story-id uint) (chapter uint) (rarity (string-utf8 16)) (uri (string-utf8 256)))
    (let 
        (
            (token-id (+ (var-get last-token-id) u1))
        )
        (asserts! (>= (stx-get-balance tx-sender) (var-get mint-price)) (err u109))
        (try! (stx-transfer? (var-get mint-price) tx-sender contract-owner))
        (try! (nft-mint? lorebit token-id tx-sender))
        (map-set token-metadata token-id {
            title: title,
            story-id: story-id,
            chapter: chapter,
            rarity: rarity,
            creator: tx-sender
        })
        (map-set token-uri token-id (some uri))
        (var-set last-token-id token-id)
        (map-set token-count tx-sender (+ (get-balance tx-sender) u1))
        ;; Award story points based on rarity
        (let ((points (if (is-eq rarity u"legendary") u100 
                         (if (is-eq rarity u"rare") u50 u25))))
            (try! (ft-mint? story-points points tx-sender))
            (map-set user-story-points tx-sender (+ (get-user-points tx-sender) points))
        )
        (ok token-id)
    )
)

;; Create a new story
(define-public (create-story (title (string-utf8 128)) (total-chapters uint) (unlock-cost uint))
    (let 
        (
            (story-id (+ (var-get total-stories) u1))
        )
        (map-set stories story-id {
            title: title,
            creator: tx-sender,
            total-chapters: total-chapters,
            unlock-cost: unlock-cost,
            created-at: stacks-block-height
        })
        (var-set total-stories story-id)
        (ok story-id)
    )
)

;; Add chapter content to a story
(define-public (add-chapter (story-id uint) (chapter uint) (content (string-utf8 1024)) (required-tokens (list 10 uint)) (unlock-cost uint))
    (let 
        (
            (story (unwrap! (map-get? stories story-id) err-story-not-found))
        )
        (asserts! (is-eq (get creator story) tx-sender) err-owner-only)
        (map-set story-chapters {story-id: story-id, chapter: chapter} {
            content: content,
            required-tokens: required-tokens,
            unlock-cost: unlock-cost
        })
        (ok true)
    )
)

;; Unlock a story chapter
(define-public (unlock-chapter (story-id uint) (chapter uint))
    (let 
        (
            (chapter-data (unwrap! (map-get? story-chapters {story-id: story-id, chapter: chapter}) err-story-not-found))
            (unlock-cost (get unlock-cost chapter-data))
            (user-points (get-user-points tx-sender))
        )
        (asserts! (>= user-points unlock-cost) err-insufficient-points)
        (asserts! (not (is-chapter-unlocked tx-sender story-id chapter)) err-already-unlocked)
        
        ;; Check if user owns required tokens
        ;; (asserts! (check-token-ownership tx-sender (get required-tokens chapter-data)) err-not-token-owner)
        
        ;; Spend story points
        (try! (ft-burn? story-points unlock-cost tx-sender))
        (map-set user-story-points tx-sender (- user-points unlock-cost))
        
        ;; Unlock chapter
        (map-set user-unlocks {user: tx-sender, story-id: story-id, chapter: chapter} true)
        (ok true)
    )
)

;; Transfer NFT
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (asserts! (is-some (nft-get-owner? lorebit token-id)) err-token-not-found)
        (nft-transfer? lorebit token-id sender recipient)
    )
)

;; Burn NFT for extra story points
(define-public (burn-for-points (token-id uint))
    (let 
        (
            (owner (unwrap! (nft-get-owner? lorebit token-id) err-token-not-found))
            (metadata (unwrap! (map-get? token-metadata token-id) err-token-not-found))
            (bonus-points (if (is-eq (get rarity metadata) u"legendary") u200 
                             (if (is-eq (get rarity metadata) u"rare") u100 u50)))
        )
        (asserts! (is-eq tx-sender owner) err-not-token-owner)
        (try! (nft-burn? lorebit token-id owner))
        (try! (ft-mint? story-points bonus-points tx-sender))
        (map-set user-story-points tx-sender (+ (get-user-points tx-sender) bonus-points))
        (ok bonus-points)
    )
)

;; Admin function to set mint price
(define-public (set-mint-price (new-price uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set mint-price new-price)
        (ok true)
    )
)

;; read only functions

;; Get last token ID
(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

;; Get token URI
(define-read-only (get-token-uri (token-id uint))
    (ok (map-get? token-uri token-id))
)

;; Get token owner
(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? lorebit token-id))
)

;; Get user balance
(define-read-only (get-balance (user principal))
    (default-to u0 (map-get? token-count user))
)

;; Get user story points
(define-read-only (get-user-points (user principal))
    (default-to u0 (map-get? user-story-points user))
)

;; Get token metadata
(define-read-only (get-token-metadata (token-id uint))
    (map-get? token-metadata token-id)
)

;; Get story info
(define-read-only (get-story (story-id uint))
    (map-get? stories story-id)
)

;; Get chapter content (only if unlocked)
(define-read-only (get-chapter-content (user principal) (story-id uint) (chapter uint))
    (if (is-chapter-unlocked user story-id chapter)
        (map-get? story-chapters {story-id: story-id, chapter: chapter})
        none
    )
)

;; Check if chapter is unlocked
(define-read-only (is-chapter-unlocked (user principal) (story-id uint) (chapter uint))
    (default-to false (map-get? user-unlocks {user: user, story-id: story-id, chapter: chapter}))
)

;; Get total stories
(define-read-only (get-total-stories)
    (var-get total-stories)
)

;; Get mint price
(define-read-only (get-mint-price)
    (var-get mint-price)
)

;; private functions

;; Check if user owns required tokens
(define-private (check-token-ownership (user principal) (token-list (list 10 uint)))
    
    ;; (fold check-single-token true token-list user)
    (ok true)
)

;; Helper function to check single token ownership
(define-private (check-single-token (token-id uint) (prev-result bool) (user principal))
    (and prev-result 
         (is-eq (some user) (nft-get-owner? lorebit token-id)))
)

;; Get contract info
(define-read-only (get-contract-info)
    {
        total-tokens: (var-get last-token-id),
        total-stories: (var-get total-stories),
        mint-price: (var-get mint-price),
        contract-owner: contract-owner
    }
)