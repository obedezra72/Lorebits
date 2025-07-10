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
(define-constant err-proposal-not-found (err u109))
(define-constant err-already-voted (err u110))
(define-constant err-proposal-closed (err u111))
(define-constant err-not-collaborator (err u112))
(define-constant err-invalid-vote (err u113))

;; data vars
(define-data-var last-token-id uint u0)
(define-data-var total-stories uint u0)
(define-data-var mint-price uint u1000000) ;; 1 STX in microSTX
(define-data-var total-proposals uint u0)
(define-data-var proposal-duration uint u144) ;; ~24 hours in blocks

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

(define-map story-collaborators {story-id: uint, user: principal} {
    role: (string-utf8 16),
    voting-power: uint,
    contribution-score: uint
})

(define-map story-proposals uint {
    story-id: uint,
    proposer: principal,
    title: (string-utf8 128),
    description: (string-utf8 512),
    option-a: (string-utf8 256),
    option-b: (string-utf8 256),
    votes-a: uint,
    votes-b: uint,
    total-votes: uint,
    end-block: uint,
    status: (string-utf8 16),
    created-at: uint
})

(define-map proposal-votes {proposal-id: uint, voter: principal} {
    choice: (string-utf8 8),
    voting-power: uint,
    timestamp: uint
})

(define-map story-governance {story-id: uint} {
    voting-threshold: uint,
    min-voting-power: uint,
    collaboration-mode: (string-utf8 16),
    governance-token-required: uint
})

;; public functions

;; Mint a new lorebit NFT
(define-public (mint-lorebit (title (string-utf8 64)) (story-id uint) (chapter uint) (rarity (string-utf8 16)) (uri (string-utf8 256)))
    (let 
        (
            (token-id (+ (var-get last-token-id) u1))
        )
        (asserts! (>= (stx-get-balance tx-sender) (var-get mint-price)) (err u200))
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

;; Story Collaboration & Voting System Functions

;; Setup governance for a story
(define-public (setup-story-governance (story-id uint) (voting-threshold uint) (min-voting-power uint) (collaboration-mode (string-utf8 16)) (governance-token-required uint))
    (let 
        (
            (story (unwrap! (map-get? stories story-id) err-story-not-found))
        )
        (asserts! (is-eq (get creator story) tx-sender) err-owner-only)
        (map-set story-governance {story-id: story-id} {
            voting-threshold: voting-threshold,
            min-voting-power: min-voting-power,
            collaboration-mode: collaboration-mode,
            governance-token-required: governance-token-required
        })
        (ok true)
    )
)

;; Add collaborator to a story
(define-public (add-collaborator (story-id uint) (collaborator principal) (role (string-utf8 16)) (voting-power uint))
    (let 
        (
            (story (unwrap! (map-get? stories story-id) err-story-not-found))
        )
        (asserts! (is-eq (get creator story) tx-sender) err-owner-only)
        (map-set story-collaborators {story-id: story-id, user: collaborator} {
            role: role,
            voting-power: voting-power,
            contribution-score: u0
        })
        (ok true)
    )
)

;; Create a story proposal
(define-public (create-proposal (story-id uint) (title (string-utf8 128)) (description (string-utf8 512)) (option-a (string-utf8 256)) (option-b (string-utf8 256)))
    (let 
        (
            (proposal-id (+ (var-get total-proposals) u1))
            (story (unwrap! (map-get? stories story-id) err-story-not-found))
            (governance (map-get? story-governance {story-id: story-id}))
            (collaborator (map-get? story-collaborators {story-id: story-id, user: tx-sender}))
        )
        (asserts! (or (is-eq (get creator story) tx-sender) (is-some collaborator)) err-not-collaborator)
        (map-set story-proposals proposal-id {
            story-id: story-id,
            proposer: tx-sender,
            title: title,
            description: description,
            option-a: option-a,
            option-b: option-b,
            votes-a: u0,
            votes-b: u0,
            total-votes: u0,
            end-block: (+ stacks-block-height (var-get proposal-duration)),
            status: u"active",
            created-at: stacks-block-height
        })
        (var-set total-proposals proposal-id)
        (ok proposal-id)
    )
)

;; Vote on a story proposal
(define-public (vote-on-proposal (proposal-id uint) (choice (string-utf8 8)))
    (let 
        (
            (proposal (unwrap! (map-get? story-proposals proposal-id) err-proposal-not-found))
            (story-id (get story-id proposal))
            (collaborator (map-get? story-collaborators {story-id: story-id, user: tx-sender}))
            (existing-vote (map-get? proposal-votes {proposal-id: proposal-id, voter: tx-sender}))
            (voting-power (calculate-voting-power tx-sender story-id))
        )
        (asserts! (or (is-eq choice u"a") (is-eq choice u"b")) err-invalid-vote)
        (asserts! (is-none existing-vote) err-already-voted)
        (asserts! (< stacks-block-height (get end-block proposal)) err-proposal-closed)
        (asserts! (is-eq (get status proposal) u"active") err-proposal-closed)
        (asserts! (> voting-power u0) err-not-collaborator)
        
        (map-set proposal-votes {proposal-id: proposal-id, voter: tx-sender} {
            choice: choice,
            voting-power: voting-power,
            timestamp: stacks-block-height
        })
        
        (if (is-eq choice u"a")
            (map-set story-proposals proposal-id (merge proposal {
                votes-a: (+ (get votes-a proposal) voting-power),
                total-votes: (+ (get total-votes proposal) voting-power)
            }))
            (map-set story-proposals proposal-id (merge proposal {
                votes-b: (+ (get votes-b proposal) voting-power),
                total-votes: (+ (get total-votes proposal) voting-power)
            }))
        )
        (ok true)
    )
)

;; Finalize a proposal
(define-public (finalize-proposal (proposal-id uint))
    (let 
        (
            (proposal (unwrap! (map-get? story-proposals proposal-id) err-proposal-not-found))
            (story-id (get story-id proposal))
            (story (unwrap! (map-get? stories story-id) err-story-not-found))
            (governance (map-get? story-governance {story-id: story-id}))
            (threshold (if (is-some governance) (get voting-threshold (unwrap-panic governance)) u10))
        )
        (asserts! (or (is-eq (get creator story) tx-sender) (is-eq (get proposer proposal) tx-sender)) err-owner-only)
        (asserts! (>= stacks-block-height (get end-block proposal)) err-proposal-closed)
        (asserts! (is-eq (get status proposal) u"active") err-proposal-closed)
        (asserts! (>= (get total-votes proposal) threshold) err-insufficient-points)
        
        (let ((winner (if (> (get votes-a proposal) (get votes-b proposal)) u"a" u"b")))
            (map-set story-proposals proposal-id (merge proposal {
                status: u"finalized"
            }))
            (try! (reward-participants proposal-id))
            (ok winner)
        )
    )
)

;; Reward voting participants
(define-public (reward-participants (proposal-id uint))
    (let 
        (
            (proposal (unwrap! (map-get? story-proposals proposal-id) err-proposal-not-found))
            (reward-amount u25)
        )
        (asserts! (is-eq (get status proposal) u"finalized") err-proposal-closed)
        (try! (ft-mint? story-points reward-amount (get proposer proposal)))
        (map-set user-story-points (get proposer proposal) (+ (get-user-points (get proposer proposal)) reward-amount))
        (ok true)
    )
)

;; Update collaborator contribution score
(define-public (update-contribution-score (story-id uint) (collaborator principal) (score-increase uint))
    (let 
        (
            (story (unwrap! (map-get? stories story-id) err-story-not-found))
            (existing-collab (unwrap! (map-get? story-collaborators {story-id: story-id, user: collaborator}) err-not-collaborator))
        )
        (asserts! (is-eq (get creator story) tx-sender) err-owner-only)
        (map-set story-collaborators {story-id: story-id, user: collaborator} 
            (merge existing-collab {
                contribution-score: (+ (get contribution-score existing-collab) score-increase)
            }))
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

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
    (map-get? story-proposals proposal-id)
)

;; Get proposal vote
(define-read-only (get-proposal-vote (proposal-id uint) (voter principal))
    (map-get? proposal-votes {proposal-id: proposal-id, voter: voter})
)

;; Get story governance settings
(define-read-only (get-story-governance (story-id uint))
    (map-get? story-governance {story-id: story-id})
)

;; Get collaborator info
(define-read-only (get-collaborator (story-id uint) (user principal))
    (map-get? story-collaborators {story-id: story-id, user: user})
)

;; Get total proposals
(define-read-only (get-total-proposals)
    (var-get total-proposals)
)

;; Check if user is collaborator
(define-read-only (is-collaborator (story-id uint) (user principal))
    (is-some (map-get? story-collaborators {story-id: story-id, user: user}))
)

;; Get active proposals for a story
(define-read-only (get-story-proposals (story-id uint))
    (ok story-id)
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

;; Calculate voting power for a user on a story
(define-private (calculate-voting-power (user principal) (story-id uint))
    (let 
        (
            (collaborator (map-get? story-collaborators {story-id: story-id, user: user}))
            (story (unwrap! (map-get? stories story-id) u0))
            (user-points (get-user-points user))
            (user-tokens (get-balance user))
        )
        (if (is-some collaborator)
            (let 
                (
                    (collab-data (unwrap-panic collaborator))
                    (base-power (get voting-power collab-data))
                    (contribution-bonus (/ (get contribution-score collab-data) u10))
                    (token-bonus (/ user-tokens u5))
                    (points-bonus (/ user-points u50))
                )
                (+ base-power contribution-bonus token-bonus points-bonus)
            )
            (if (is-eq (get creator story) user)
                (+ u50 (/ user-tokens u3) (/ user-points u25))
                u0
            )
        )
    )
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