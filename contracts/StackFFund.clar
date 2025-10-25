
;; StackFFund
;; <add a description here>


;; Constants
(define-constant contract-owner tx-sender)
(define-constant min-investment u1000000) ;; 1 STX minimum investment
(define-constant max-investment u1000000000) ;; 1000 STX maximum investment
(define-constant voting-period u144) ;; ~1 day in blocks
(define-constant min-vote-threshold u500000) ;; Minimum votes needed
(define-constant min-title-length u4)
(define-constant max-title-length u50)
(define-constant min-description-length u10)
(define-constant max-description-length u500)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INVALID-AMOUNT (err u402))
(define-constant ERR-PROJECT-NOT-FOUND (err u404))
(define-constant ERR-PROJECT-EXPIRED (err u405))
(define-constant ERR-ALREADY-VOTED (err u406))
(define-constant ERR-INVALID-TITLE (err u407))
(define-constant ERR-INVALID-DESCRIPTION (err u408))
(define-constant ERR-INVALID-PROJECT-ID (err u409))
(define-constant ERR-MAX-INVESTMENT-EXCEEDED (err u410))
(define-constant ERR-ZERO-AMOUNT (err u411))
(define-constant ERR-PROJECT-INACTIVE (err u412))
(define-constant ERR-DUPLICATE-TITLE (err u413))

;; Data Variables
(define-data-var project-counter uint u0)

;; Data Maps
(define-map projects 
    { project-id: uint }
    {
        creator: principal,
        title: (string-ascii 50),
        description: (string-ascii 500),
        funding-goal: uint,
        current-amount: uint,
        status: (string-ascii 20),
        end-block: uint,
        creation-block: uint,
        last-updated: uint
    }
)

(define-map project-titles
    { title: (string-ascii 50) }
    { exists: bool }
)

(define-map investments
    { project-id: uint, investor: principal }
    {
        amount: uint,
        timestamp: uint,
        last-updated: uint
    }
)

(define-map votes
    { project-id: uint, voter: principal }
    {
        vote: bool,
        timestamp: uint
    }
)

(define-map vote-counts
    { project-id: uint }
    {
        total-votes: uint,
        positive-votes: uint,
        negative-votes: uint,
        last-updated: uint
    }
)

;; Private Helper Functions

;; Validate title
(define-private (is-valid-title (title (string-ascii 50)))
    (let ((title-length (len title)))
        (and 
            (>= title-length min-title-length)
            (<= title-length max-title-length)
            (not (is-eq title ""))
            (is-none (map-get? project-titles { title: title })))))

;; Validate description
(define-private (is-valid-description (description (string-ascii 500)))
    (let ((desc-length (len description)))
        (and 
            (>= desc-length min-description-length)
            (<= desc-length max-description-length)
            (not (is-eq description "")))))

;; Validate project ID
(define-private (is-valid-project-id (project-id uint))
    (and 
        (> project-id u0)
        (<= project-id (var-get project-counter))))

;; Validate investment amount
(define-private (is-valid-amount (amount uint))
    (and 
        (> amount u0)
        (>= amount min-investment)
        (<= amount max-investment)))

;; Check if project is active
(define-private (is-project-active (project-id uint))
    (match (map-get? projects { project-id: project-id })
        project (is-eq (get status project) "active")
        false))

;; Create or update vote counts with validation
(define-private (set-vote-counts (project-id uint))
    (begin
        (asserts! (is-valid-project-id project-id) ERR-INVALID-PROJECT-ID)
        (ok (map-set vote-counts
            { project-id: project-id }
            {
                total-votes: u0,
                positive-votes: u0,
                negative-votes: u0,
                last-updated: block-height
            }))))

;; Public Functions

;; Create a new project with validation
(define-public (create-project 
    (title (string-ascii 50)) 
    (description (string-ascii 500))
    (funding-goal uint))
    (begin
        (asserts! (is-valid-title title) ERR-INVALID-TITLE)
        (asserts! (is-valid-description description) ERR-INVALID-DESCRIPTION)
        (asserts! (is-valid-amount funding-goal) ERR-INVALID-AMOUNT)
        
        (let ((project-id (+ (var-get project-counter) u1)))
            (begin
                (map-set projects 
                    { project-id: project-id }
                    {
                        creator: tx-sender,
                        title: title,
                        description: description,
                        funding-goal: funding-goal,
                        current-amount: u0,
                        status: "active",
                        end-block: (+ block-height voting-period),
                        creation-block: block-height,
                        last-updated: block-height
                    })
                (map-set project-titles
                    { title: title }
                    { exists: true })
                (try! (set-vote-counts project-id))
                (var-set project-counter project-id)
                (ok project-id)))))

;; Invest in a project with validation
(define-public (invest (project-id uint) (amount uint))
    (begin
        (asserts! (is-valid-project-id project-id) ERR-INVALID-PROJECT-ID)
        (asserts! (is-valid-amount amount) ERR-INVALID-AMOUNT)
        (asserts! (is-project-active project-id) ERR-PROJECT-INACTIVE)
        
        (let ((project (unwrap! (map-get? projects { project-id: project-id })
                               ERR-PROJECT-NOT-FOUND))
              (current-investment (default-to 
                                    { amount: u0, timestamp: u0, last-updated: u0 }
                                    (map-get? investments 
                                        { project-id: project-id, investor: tx-sender }))))
            (asserts! (< (+ amount (get current-amount project)) max-investment)
                     ERR-MAX-INVESTMENT-EXCEEDED)
            (asserts! (< block-height (get end-block project))
                     ERR-PROJECT-EXPIRED)
            
            (begin
                (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
                (map-set projects 
                    { project-id: project-id }
                    (merge project 
                        { 
                            current-amount: (+ (get current-amount project) amount),
                            last-updated: block-height
                        }))
                (map-set investments 
                    { project-id: project-id, investor: tx-sender }
                    { 
                        amount: (+ amount (get amount current-investment)),
                        timestamp: block-height,
                        last-updated: block-height
                    })
                (ok true)))))
