
;; title: Community-Service-Credit-System
;; version: 1.0.0
;; summary: Soulbound token system for tracking and validating community service contributions
;; description: A smart contract that issues non-transferable tokens to volunteers based on validated service contributions

(define-constant CONTRACT_OWNER tx-sender)

(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_HOURS (err u101))
(define-constant ERR_ORGANIZATION_NOT_FOUND (err u102))
(define-constant ERR_VOLUNTEER_NOT_FOUND (err u103))
(define-constant ERR_CONTRIBUTION_NOT_FOUND (err u104))
(define-constant ERR_ALREADY_VALIDATED (err u105))
(define-constant ERR_INVALID_ORGANIZATION (err u106))
(define-constant ERR_SELF_VALIDATION (err u107))

(define-data-var next-contribution-id uint u1)
(define-data-var next-organization-id uint u1)

(define-map organizations
  { organization-id: uint }
  {
    name: (string-utf8 100),
    lead: principal,
    active: bool,
    total-hours-validated: uint,
    volunteers-served: uint
  }
)

(define-map organization-leads
  { lead: principal }
  { organization-id: uint }
)

(define-map volunteer-profiles
  { volunteer: principal }
  {
    total-credits: uint,
    total-hours: uint,
    contributions-count: uint,
    reputation-score: uint,
    first-contribution-block: uint
  }
)

(define-map service-contributions
  { contribution-id: uint }
  {
    volunteer: principal,
    organization-id: uint,
    hours: uint,
    description: (string-utf8 200),
    submission-block: uint,
    validated: bool,
    validator: (optional principal),
    validation-block: (optional uint)
  }
)

(define-map volunteer-organization-history
  { volunteer: principal, organization-id: uint }
  {
    total-hours: uint,
    total-contributions: uint,
    last-contribution-block: uint
  }
)

(define-public (register-organization (name (string-utf8 100)))
  (let
    (
      (organization-id (var-get next-organization-id))
    )
    (asserts! (> (len name) u0) ERR_INVALID_ORGANIZATION)
    (map-set organizations
      { organization-id: organization-id }
      {
        name: name,
        lead: tx-sender,
        active: true,
        total-hours-validated: u0,
        volunteers-served: u0
      }
    )
    (map-set organization-leads
      { lead: tx-sender }
      { organization-id: organization-id }
    )
    (var-set next-organization-id (+ organization-id u1))
    (ok organization-id)
  )
)

(define-public (submit-contribution (organization-id uint) (hours uint) (description (string-utf8 200)))
  (let
    (
      (contribution-id (var-get next-contribution-id))
      (current-block stacks-block-height)
    )
    (asserts! (> hours u0) ERR_INVALID_HOURS)
    (asserts! (> (len description) u0) ERR_INVALID_HOURS)
    (asserts! (is-some (map-get? organizations { organization-id: organization-id })) ERR_ORGANIZATION_NOT_FOUND)
    (map-set service-contributions
      { contribution-id: contribution-id }
      {
        volunteer: tx-sender,
        organization-id: organization-id,
        hours: hours,
        description: description,
        submission-block: current-block,
        validated: false,
        validator: none,
        validation-block: none
      }
    )
    (var-set next-contribution-id (+ contribution-id u1))
    (ok contribution-id)
  )
)

(define-public (validate-contribution (contribution-id uint))
  (let
    (
      (contribution (unwrap! (map-get? service-contributions { contribution-id: contribution-id }) ERR_CONTRIBUTION_NOT_FOUND))
      (organization-info (unwrap! (map-get? organizations { organization-id: (get organization-id contribution) }) ERR_ORGANIZATION_NOT_FOUND))
      (volunteer (get volunteer contribution))
      (hours (get hours contribution))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender (get lead organization-info)) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq tx-sender volunteer)) ERR_SELF_VALIDATION)
    (asserts! (not (get validated contribution)) ERR_ALREADY_VALIDATED)
    (map-set service-contributions
      { contribution-id: contribution-id }
      (merge contribution {
        validated: true,
        validator: (some tx-sender),
        validation-block: (some current-block)
      })
    )
    (unwrap-panic (award-credits volunteer (get organization-id contribution) hours))
    (unwrap-panic (update-organization-stats (get organization-id contribution) volunteer hours))
    (ok true)
  )
)

(define-private (award-credits (volunteer principal) (organization-id uint) (hours uint))
  (let
    (
      (existing-profile (map-get? volunteer-profiles { volunteer: volunteer }))
      (current-block stacks-block-height)
      (credits-to-award hours)
    )
    (match existing-profile
      existing
      (map-set volunteer-profiles
        { volunteer: volunteer }
        {
          total-credits: (+ (get total-credits existing) credits-to-award),
          total-hours: (+ (get total-hours existing) hours),
          contributions-count: (+ (get contributions-count existing) u1),
          reputation-score: (calculate-reputation-score (+ (get total-hours existing) hours) (+ (get contributions-count existing) u1) (get first-contribution-block existing)),
          first-contribution-block: (get first-contribution-block existing)
        }
      )
      (map-set volunteer-profiles
        { volunteer: volunteer }
        {
          total-credits: credits-to-award,
          total-hours: hours,
          contributions-count: u1,
          reputation-score: (calculate-reputation-score hours u1 current-block),
          first-contribution-block: current-block
        }
      )
    )
    (unwrap-panic (update-volunteer-organization-history volunteer organization-id hours))
    (ok true)
  )
)

(define-private (update-volunteer-organization-history (volunteer principal) (organization-id uint) (hours uint))
  (let
    (
      (current-block stacks-block-height)
      (existing-history (map-get? volunteer-organization-history { volunteer: volunteer, organization-id: organization-id }))
    )
    (match existing-history
      existing
      (map-set volunteer-organization-history
        { volunteer: volunteer, organization-id: organization-id }
        {
          total-hours: (+ (get total-hours existing) hours),
          total-contributions: (+ (get total-contributions existing) u1),
          last-contribution-block: current-block
        }
      )
      (map-set volunteer-organization-history
        { volunteer: volunteer, organization-id: organization-id }
        {
          total-hours: hours,
          total-contributions: u1,
          last-contribution-block: current-block
        }
      )
    )
    (ok true)
  )
)

(define-private (update-organization-stats (organization-id uint) (volunteer principal) (hours uint))
  (let
    (
      (org-info (unwrap! (map-get? organizations { organization-id: organization-id }) ERR_ORGANIZATION_NOT_FOUND))
      (is-new-volunteer (is-none (map-get? volunteer-organization-history { volunteer: volunteer, organization-id: organization-id })))
    )
    (map-set organizations
      { organization-id: organization-id }
      {
        name: (get name org-info),
        lead: (get lead org-info),
        active: (get active org-info),
        total-hours-validated: (+ (get total-hours-validated org-info) hours),
        volunteers-served: (if is-new-volunteer (+ (get volunteers-served org-info) u1) (get volunteers-served org-info))
      }
    )
    (ok true)
  )
)

(define-private (calculate-reputation-score (total-hours uint) (contributions-count uint) (first-contribution-block uint))
  (let
    (
      (longevity-bonus (if (> (- stacks-block-height first-contribution-block) u10000) u50 u0))
      (consistency-bonus (if (> contributions-count u10) u25 u0))
      (base-score (/ (* total-hours u10) u1))
    )
    (+ base-score longevity-bonus consistency-bonus)
  )
)

(define-public (deactivate-organization (organization-id uint))
  (let
    (
      (org-info (unwrap! (map-get? organizations { organization-id: organization-id }) ERR_ORGANIZATION_NOT_FOUND))
    )
    (asserts! (or (is-eq tx-sender (get lead org-info)) (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)
    (map-set organizations
      { organization-id: organization-id }
      (merge org-info { active: false })
    )
    (ok true)
  )
)

(define-public (transfer-organization-leadership (organization-id uint) (new-lead principal))
  (let
    (
      (org-info (unwrap! (map-get? organizations { organization-id: organization-id }) ERR_ORGANIZATION_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get lead org-info)) ERR_UNAUTHORIZED)
    (map-delete organization-leads { lead: tx-sender })
    (map-set organization-leads { lead: new-lead } { organization-id: organization-id })
    (map-set organizations
      { organization-id: organization-id }
      (merge org-info { lead: new-lead })
    )
    (ok true)
  )
)

(define-read-only (get-volunteer-profile (volunteer principal))
  (map-get? volunteer-profiles { volunteer: volunteer })
)

(define-read-only (get-organization-info (organization-id uint))
  (map-get? organizations { organization-id: organization-id })
)

(define-read-only (get-contribution-details (contribution-id uint))
  (map-get? service-contributions { contribution-id: contribution-id })
)

(define-read-only (get-volunteer-organization-history (volunteer principal) (organization-id uint))
  (map-get? volunteer-organization-history { volunteer: volunteer, organization-id: organization-id })
)

(define-read-only (get-organization-by-lead (lead principal))
  (map-get? organization-leads { lead: lead })
)

(define-read-only (get-total-system-stats)
  {
    total-organizations: (- (var-get next-organization-id) u1),
    total-contributions: (- (var-get next-contribution-id) u1)
  }
)

(define-read-only (verify-volunteer-credits (volunteer principal) (min-credits uint))
  (match (map-get? volunteer-profiles { volunteer: volunteer })
    profile (>= (get total-credits profile) min-credits)
    false
  )
)

(define-read-only (get-reputation-tier (volunteer principal))
  (match (map-get? volunteer-profiles { volunteer: volunteer })
    profile
    (let ((score (get reputation-score profile)))
      (if (>= score u500)
        "Gold"
        (if (>= score u200)
          "Silver"
          (if (>= score u50)
            "Bronze"
            "Beginner"
          )
        )
      )
    )
    "Unregistered"
  )
)

