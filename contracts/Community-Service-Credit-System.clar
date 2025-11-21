
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
(define-constant ERR_BADGE_ALREADY_EARNED (err u108))
(define-constant ERR_APPEAL_NOT_FOUND (err u109))
(define-constant ERR_APPEAL_ALREADY_RESOLVED (err u110))
(define-constant ERR_CANNOT_APPEAL_VALIDATED (err u111))
(define-constant ERR_APPEAL_ALREADY_EXISTS (err u112))

(define-constant BADGE_FIRST_CONTRIBUTION u1)
(define-constant BADGE_10_HOURS u2)
(define-constant BADGE_50_HOURS u3)
(define-constant BADGE_100_HOURS u4)
(define-constant BADGE_500_HOURS u5)
(define-constant BADGE_10_CONTRIBUTIONS u6)
(define-constant BADGE_50_CONTRIBUTIONS u7)
(define-constant BADGE_MULTI_ORG u8)
(define-constant BADGE_LONG_TERM u9)
(define-constant BADGE_REPUTATION_GOLD u10)

(define-data-var next-contribution-id uint u1)
(define-data-var next-organization-id uint u1)
(define-data-var next-appeal-id uint u1)

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

(define-map volunteer-badges
  { volunteer: principal, badge-id: uint }
  {
    earned: bool,
    earned-block: uint
  }
)

(define-map volunteer-badge-count
  { volunteer: principal }
  { total-badges: uint }
)

(define-map contribution-appeals
  { appeal-id: uint }
  {
    contribution-id: uint,
    volunteer: principal,
    organization-id: uint,
    reason: (string-utf8 300),
    submission-block: uint,
    resolved: bool,
    resolution: (optional (string-utf8 300)),
    resolver: (optional principal),
    resolution-block: (optional uint),
    approved: (optional bool)
  }
)

(define-map contribution-appeal-lookup
  { contribution-id: uint }
  { appeal-id: uint }
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
    (unwrap-panic (check-and-award-badges volunteer))
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

(define-private (check-and-award-badges (volunteer principal))
  (let
    (
      (profile (unwrap! (map-get? volunteer-profiles { volunteer: volunteer }) (ok false)))
      (total-hours (get total-hours profile))
      (total-contributions (get contributions-count profile))
      (reputation (get reputation-score profile))
      (first-block (get first-contribution-block profile))
      (blocks-active (- stacks-block-height first-block))
    )
    (if (is-eq total-contributions u1)
      (unwrap-panic (award-badge volunteer BADGE_FIRST_CONTRIBUTION))
      true
    )
    (if (>= total-hours u10)
      (unwrap-panic (award-badge volunteer BADGE_10_HOURS))
      true
    )
    (if (>= total-hours u50)
      (unwrap-panic (award-badge volunteer BADGE_50_HOURS))
      true
    )
    (if (>= total-hours u100)
      (unwrap-panic (award-badge volunteer BADGE_100_HOURS))
      true
    )
    (if (>= total-hours u500)
      (unwrap-panic (award-badge volunteer BADGE_500_HOURS))
      true
    )
    (if (>= total-contributions u10)
      (unwrap-panic (award-badge volunteer BADGE_10_CONTRIBUTIONS))
      true
    )
    (if (>= total-contributions u50)
      (unwrap-panic (award-badge volunteer BADGE_50_CONTRIBUTIONS))
      true
    )
    (if (>= (count-organizations-worked volunteer) u3)
      (unwrap-panic (award-badge volunteer BADGE_MULTI_ORG))
      true
    )
    (if (>= blocks-active u10000)
      (unwrap-panic (award-badge volunteer BADGE_LONG_TERM))
      true
    )
    (if (>= reputation u500)
      (unwrap-panic (award-badge volunteer BADGE_REPUTATION_GOLD))
      true
    )
    (ok true)
  )
)

(define-private (award-badge (volunteer principal) (badge-id uint))
  (let
    (
      (existing-badge (map-get? volunteer-badges { volunteer: volunteer, badge-id: badge-id }))
      (current-block stacks-block-height)
    )
    (match existing-badge
      badge
      (ok false)
      (begin
        (map-set volunteer-badges
          { volunteer: volunteer, badge-id: badge-id }
          { earned: true, earned-block: current-block }
        )
        (let
          (
            (badge-count-data (map-get? volunteer-badge-count { volunteer: volunteer }))
          )
          (match badge-count-data
            count-data
            (map-set volunteer-badge-count
              { volunteer: volunteer }
              { total-badges: (+ (get total-badges count-data) u1) }
            )
            (map-set volunteer-badge-count
              { volunteer: volunteer }
              { total-badges: u1 }
            )
          )
        )
        (ok true)
      )
    )
  )
)

(define-private (count-organizations-worked (volunteer principal))
  (get count (fold count-org-if-worked (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20) { volunteer: volunteer, count: u0 }))
)

(define-private (count-org-if-worked (org-id uint) (context { volunteer: principal, count: uint }))
  (let
    (
      (volunteer (get volunteer context))
      (history (map-get? volunteer-organization-history { volunteer: volunteer, organization-id: org-id }))
    )
    (match history
      h
      { volunteer: volunteer, count: (+ (get count context) u1) }
      context
    )
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

(define-public (submit-appeal (contribution-id uint) (reason (string-utf8 300)))
  (let
    (
      (contribution (unwrap! (map-get? service-contributions { contribution-id: contribution-id }) ERR_CONTRIBUTION_NOT_FOUND))
      (appeal-id (var-get next-appeal-id))
      (current-block stacks-block-height)
      (existing-appeal (map-get? contribution-appeal-lookup { contribution-id: contribution-id }))
    )
    (asserts! (is-eq tx-sender (get volunteer contribution)) ERR_UNAUTHORIZED)
    (asserts! (not (get validated contribution)) ERR_CANNOT_APPEAL_VALIDATED)
    (asserts! (> (len reason) u0) ERR_INVALID_HOURS)
    (asserts! (is-none existing-appeal) ERR_APPEAL_ALREADY_EXISTS)
    (map-set contribution-appeals
      { appeal-id: appeal-id }
      {
        contribution-id: contribution-id,
        volunteer: tx-sender,
        organization-id: (get organization-id contribution),
        reason: reason,
        submission-block: current-block,
        resolved: false,
        resolution: none,
        resolver: none,
        resolution-block: none,
        approved: none
      }
    )
    (map-set contribution-appeal-lookup
      { contribution-id: contribution-id }
      { appeal-id: appeal-id }
    )
    (var-set next-appeal-id (+ appeal-id u1))
    (ok appeal-id)
  )
)

(define-public (resolve-appeal (appeal-id uint) (approved bool) (resolution-text (string-utf8 300)))
  (let
    (
      (appeal (unwrap! (map-get? contribution-appeals { appeal-id: appeal-id }) ERR_APPEAL_NOT_FOUND))
      (organization-info (unwrap! (map-get? organizations { organization-id: (get organization-id appeal) }) ERR_ORGANIZATION_NOT_FOUND))
      (current-block stacks-block-height)
    )
    (asserts! (or (is-eq tx-sender (get lead organization-info)) (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)
    (asserts! (not (get resolved appeal)) ERR_APPEAL_ALREADY_RESOLVED)
    (map-set contribution-appeals
      { appeal-id: appeal-id }
      (merge appeal {
        resolved: true,
        resolution: (some resolution-text),
        resolver: (some tx-sender),
        resolution-block: (some current-block),
        approved: (some approved)
      })
    )
    (if approved
      (let
        (
          (contribution (unwrap! (map-get? service-contributions { contribution-id: (get contribution-id appeal) }) ERR_CONTRIBUTION_NOT_FOUND))
          (volunteer (get volunteer appeal))
          (hours (get hours contribution))
        )
        (map-set service-contributions
          { contribution-id: (get contribution-id appeal) }
          (merge contribution {
            validated: true,
            validator: (some tx-sender),
            validation-block: (some current-block)
          })
        )
        (unwrap-panic (award-credits volunteer (get organization-id appeal) hours))
        (unwrap-panic (update-organization-stats (get organization-id appeal) volunteer hours))
        (ok true)
      )
      (ok true)
    )
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

(define-read-only (get-volunteer-badge (volunteer principal) (badge-id uint))
  (map-get? volunteer-badges { volunteer: volunteer, badge-id: badge-id })
)

(define-read-only (get-volunteer-total-badges (volunteer principal))
  (match (map-get? volunteer-badge-count { volunteer: volunteer })
    count-data (get total-badges count-data)
    u0
  )
)

(define-read-only (has-badge (volunteer principal) (badge-id uint))
  (match (map-get? volunteer-badges { volunteer: volunteer, badge-id: badge-id })
    badge (get earned badge)
    false
  )
)

(define-read-only (get-badge-name (badge-id uint))
  (if (is-eq badge-id BADGE_FIRST_CONTRIBUTION)
    "First Contribution"
    (if (is-eq badge-id BADGE_10_HOURS)
      "10 Hours"
      (if (is-eq badge-id BADGE_50_HOURS)
        "50 Hours"
        (if (is-eq badge-id BADGE_100_HOURS)
          "100 Hours"
          (if (is-eq badge-id BADGE_500_HOURS)
            "500 Hours"
            (if (is-eq badge-id BADGE_10_CONTRIBUTIONS)
              "10 Contributions"
              (if (is-eq badge-id BADGE_50_CONTRIBUTIONS)
                "50 Contributions"
                (if (is-eq badge-id BADGE_MULTI_ORG)
                  "Multi-Organization"
                  (if (is-eq badge-id BADGE_LONG_TERM)
                    "Long-Term Volunteer"
                    (if (is-eq badge-id BADGE_REPUTATION_GOLD)
                      "Gold Reputation"
                      "Unknown"
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
)

(define-read-only (get-appeal-details (appeal-id uint))
  (map-get? contribution-appeals { appeal-id: appeal-id })
)

(define-read-only (get-appeal-by-contribution (contribution-id uint))
  (match (map-get? contribution-appeal-lookup { contribution-id: contribution-id })
    lookup-data (map-get? contribution-appeals { appeal-id: (get appeal-id lookup-data) })
    none
  )
)

(define-read-only (has-pending-appeal (contribution-id uint))
  (match (map-get? contribution-appeal-lookup { contribution-id: contribution-id })
    lookup-data
    (match (map-get? contribution-appeals { appeal-id: (get appeal-id lookup-data) })
      appeal (not (get resolved appeal))
      false
    )
    false
  )
)

