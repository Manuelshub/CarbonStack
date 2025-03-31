;; Title: CarbonStack - Decentralized Carbon Credit Marketplace
;; Author: CarbonStack Team
;; Description: Smart contracts for tokenized carbon credits with geographic validation

;; ========================================================================
;; Carbon Credit Token (CCT) Contract
;; ========================================================================
;; Defines the fungible token representing carbon credits

(define-fungible-token carbon-credit)

;; Contract owner/admin
(define-data-var admin principal tx-sender)

;; Constants
(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-PROJECT-NOT-VERIFIED u101)
(define-constant ERR-INVALID-AMOUNT u102)
(define-constant ERR-TRANSFER-FAILED u103)
(define-constant ERR-PROJECT-EXISTS u104)
(define-constant ERR-INVALID-PROJECT u105)
(define-constant ERR-GEOGRAPHIC-PROOF-FAILED u106)
(define-constant ERR-VALIDATOR-NOT-REGISTERED u107)

;; Track retired credits (permanently taken out of circulation)
(define-map retired-credits 
  { owner: principal, timestamp: uint }
  { amount: uint, project-id: uint }
)

;; Total retired amount per user
(define-map total-retired principal uint)

;; Initialize the contract with admin
(define-public (initialize (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR-NOT-AUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)

;; Mint new carbon credits
;; Only callable by admin when a project is verified
(define-public (mint (amount uint) (recipient principal) (project-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err ERR-NOT-AUTHORIZED))
    (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))
    (asserts! (contract-call? .project-registry is-project-verified project-id) (err ERR-PROJECT-NOT-VERIFIED))
    (match (ft-mint? carbon-credit amount recipient)
      success (begin
        (print { action: "carbon-credit-minted", amount: amount, recipient: recipient, project-id: project-id })
        (ok success)
      )
      error (err ERR-TRANSFER-FAILED)
    )
  )
)

;; Retire carbon credits (take out of circulation to claim offset)
(define-public (retire (amount uint) (project-id uint))
  (begin
    (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))
    (asserts! (contract-call? .project-registry project-exists project-id) (err ERR-INVALID-PROJECT))
    
    (match (ft-burn? carbon-credit amount tx-sender)
      success (begin
        (map-set retired-credits 
            { owner: tx-sender, timestamp: block-height } 
            { amount: amount, project-id: project-id })
            
        ;; Update user's total retired amount
        (match (map-get? total-retired tx-sender)
          prev-amount (map-set total-retired tx-sender (+ prev-amount amount))
          (map-set total-retired tx-sender amount)
        )
        
        (print { action: "carbon-credit-retired", amount: amount, owner: tx-sender, project-id: project-id })
        (ok success)
      )
      error (err ERR-TRANSFER-FAILED)
    )
  )
)

;; Get total retired credits for a user
(define-read-only (get-total-retired (user principal))
  (default-to u0 (map-get? total-retired user))
)

;; Get info about a specific retirement event
(define-read-only (get-retirement-info (owner principal) (timestamp uint))
  (map-get? retired-credits { owner: owner, timestamp: timestamp })
)

;; ========================================================================
;; Project Registry Contract
;; ========================================================================
;; Tracks all environmental projects and their verification status

;; Project structure
(define-map projects uint 
  {
    name: (string-ascii 100),
    description: (string-ascii 500),
    location: {
      latitude: int,
      longitude: int,
      region-code: (string-ascii 10)
    },
    project-type: (string-ascii 50),
    verified: bool,
    total-credits: uint,
    remaining-credits: uint,
    created-at: uint,
    owner: principal
  }
)
;; ========================================================================
;; Project Registry Contract
;; ========================================================================
;; Tracks all environmental projects and their verification status

;; Project structure
(define-map projects uint 
  {
    name: (string-ascii 100),
    description: (string-ascii 500),
    location: {
      latitude: int,
      longitude: int,
      region-code: (string-ascii 10)
    },
    project-type: (string-ascii 50),
    verified: bool,
    total-credits: uint,
    remaining-credits: uint,
    created-at: uint,
    owner: principal
  }
)

;; Project counter
(define-data-var project-id-counter uint u0)

;; Project to validators mapping
(define-map project-validators 
  { project-id: uint, validator: principal } 
  bool
)

;; Admin 
(define-data-var registry-admin principal tx-sender)
