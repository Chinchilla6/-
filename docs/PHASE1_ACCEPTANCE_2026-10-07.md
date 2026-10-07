# Phase 1 acceptance — 2026-10-07

## Verified live inventory

The requested candidate seed and original admin implementation already existed on main and in Supabase. They were reused, not seeded again.

| Item | Count |
|---|---:|
| Canonical wger exercises | 939 |
| Classified GLUTE profiles | 18 |
| Classified HIP profiles | 42 |
| AUTO_SUGGESTED relationships | 77 |
| REVIEWED relationships | 0 |
| Production session feedback rows | 0 |

Relationship distribution: PROGRESSION 28, REGRESSION 22, ALTERNATIVE 11, PREPARATION 4, ACTIVATION 4, MOBILITY 6, RELEASE 2. Profiles also remain AUTO_SUGGESTED. All canonical exercise IDs remain in the original tables; the current ID checksum is `92ec9100ad335fa1227ede81469c9619`. The older 861 figure was a previous upstream snapshot.

## Changes delivered in this continuation

- `database/migrations/20261007123207_phase1_graph_runtime_hardening.sql`: additive migration applied to the existing project. Introduces `exercise_edge_eligible`, recursive graph validation, approval transition/cycle guards and serialized reviews; updates existing engine functions in place, preserving signatures. No new tables or canonical ID changes.
- `supabase/functions/progression-admin/index.ts` + `handler.mjs`: server-side Auth verification and app_metadata authorization; body/patch validation; reviewer identity from verified user; paginated graph/list/audit reads; corrected Pages redirect; deployed to the existing Edge Function.
- `admin/progression-review/index.html` + `graph.mjs`: full graph including isolated classified profiles, connected-component filter, incoming/multi-hop edges, expanded comparison conditions/contraindications/evidence/deltas, prefilled edit data, audit history and visible request errors.
- `database/tests/phase1_runtime_hardening.sql`: transactional SQL integration tests.
- `tests/progression-admin.test.mjs` + `.github/workflows/test-progression-review.yml`: repeatable Node test suite and CI.

Original migrations remain unchanged: phase1 schema, 60-profile seed, 77-candidate seed, edit guard and AI insert guard.

## Protection and runtime behavior

Every POST action requires a bearer token verified by Supabase Auth and server-owned `app_metadata.role=admin` or `is_admin=true`. User-editable `user_metadata` never grants access. The reviewer parameter is derived from the verified identity. Public GET redirects to the login shell; no relationship data is rendered before authorization. Client code contains only a publishable key.

Database RLS exposes only REVIEWED edges to ordinary app users, restricts feedback to its owner, and denies direct review RPC execution to anon/authenticated roles. The service key stays in the server. All review writes produce actor/snapshot audit records; edits reset approval. Approval that would create an arbitrary-length progression cycle is blocked, with reviews serialized to avoid competing approvals.

Both `evaluate_exercise_progression` and `decide_exercise_progression` require REVIEWED relationships and check supported edge-specific conditions. Supported keys are `min_completed_sessions`, `min_completion_rate`, `min_quality_score`, `max_pain_score`, `max_rpe`, and `priority`. Unknown or malformed keys fail closed and block approval. Nonempty contraindications currently require a future context-aware eligibility implementation, so such edges are excluded from runtime selection rather than presumed safe. Rejected target classifications are excluded.

Feedback mastery uses completed sessions. The most adverse pain/quality/readiness/fatigue in the latest two sessions prevents averages from hiding deterioration. Safety symptoms return RECOVERY. No-history and no-approved-edge fallbacks return KEEP. REPS_UP, LOAD_UP and SETS_UP precede graph progression; an explicit exhausted flag allows a loaded exercise to reach graph progression rather than remaining stuck on LOAD_UP.

Example authenticated client RPC:

```javascript
await supabase.rpc('decide_exercise_progression', {
  p_exercise_id: 265,
  p_current_reps: 12,
  p_current_sets: 4,
  p_current_weight: 40,
  p_target_rep_max: 12,
  p_target_set_max: 4,
  p_goal: 'LOAD',
  p_need_alternative: false,
  p_in_exercise_progression_exhausted: true
})
```

The current user is inferred from Auth when `p_user_id` is omitted. Engine decisions are product logic, not a diagnosis. A broader clinical eligibility model, equipment context and versioned prescription thresholds remain future scope.

## Test results

- Node API/graph tests: **14 passed, 0 failed**. Includes missing/invalid auth, ordinary-user and forged metadata denial, trusted reviewer identity, invalid JSON/IDs/actions, forbidden patch fields, approve-with-edit rejection, CORS, published path, multi-hop/incoming graph, cycle termination, isolated profiles and 601-row pagination.
- Existing six-section SQL smoke suite: **passed**, pending evaluator output zero, approved evaluator visibility, direct edit block, AI pre-approved insert denial, integrity constraints, decision ordering and safety block.
- New SQL suite: **passed**, edge conditions including RPE/missing/malformed inputs, three-node cycles, cycle approval denial, edit reset, session-count gate, exhausted loaded progression, latest pain, audit actor, KEEP, reviewed-only regression/alternative, rejected alternative exclusion, relationship/feedback RLS and direct-RPC privilege isolation.
- UI module syntax: **passed**.
- Deployed unauthenticated POST: **401 Authentication required**.
- GitHub Actions CI run `37623311555`: **success**, all 14 tests passed on the committed code.
- GitHub Pages deployment run `37623311663`: **failed** at Configure Pages because this repository has no enabled Pages site. The previous deployment had the same failure. The connected GitHub App lacks administration access, so enabling the site is an external prerequisite. The UI code is committed, but the public page, visual/browser acceptance and email login round trip are **not yet verified**.
- Every synthetic approval/user/feedback record from SQL tests was rolled back. Final relationship state remains 77 AUTO_SUGGESTED / 0 REVIEWED and zero production feedback.

## Human-review and security findings

The designated reviewer account is provisioned with the admin role and still requires email verification through the login flow. No AI task has approved any production relationship.

To finish hosted UI acceptance, the repository owner must open [Pages settings](https://github.com/Chinchilla6/-/settings/pages) and set Build and deployment → Source to GitHub Actions, then rerun the [deployment workflow](https://github.com/Chinchilla6/-/actions/workflows/deploy-progression-review.yml). The intended page is `https://chinchilla6.github.io/-/progression-review/`. In Supabase Auth URL Configuration, this exact page URL must be an allowed redirect destination; that setting cannot be inspected by the current MCP tools. Complete the email login round trip and verify list/graph/validation access after publishing. Do not count this phase as fully accepted until those checks pass. No token, password or service key should be pasted into chat.

Graph validation currently reports 46 profiles without reviewed progression, 46 without reviewed regression and 77 relationships with an evidence level but no attached source. These are review/coverage findings, not database corruption. No production progression cycles or unsupported conditions were found. Candidate B/C evidence labels are provisional and must not be presented as verified clinical evidence until a human attaches/checks actual sources.

Supabase advisors report existing closed-by-default RLS tables without policies (including the private audit/config tables), a pre-existing pg_net extension in public, and disabled leaked-password protection. No graph tables lack RLS. See [extension remediation](https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public), [closed-by-default RLS information](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) and [Auth password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). These project-wide settings were not changed by this phase.

## CORE next phase

Reuse the same tables, workflow and engine. First review a bounded GLUTE/HIP chain to confirm actual reviewer workload. Then select approximately 40–80 CORE exercises by movement intent, preserving canonical IDs, with BRACING, ANTI_EXTENSION, ANTI_ROTATION, ANTI_LATERAL_FLEXION, FLEXION, ROTATION and DYNAMIC_STABILITY patterns. Add multidimensional AUTO_SUGGESTED profiles; draft candidate relationships with explicit changes in support/load/ROM/control and real source links. Never derive approval from difficulty/name/embedding/muscle similarity. Human-review each edge independently, including regression and alternatives. Extend admin family filtering and CORE-specific context/eligibility tests before allowing recommendations. Graph validation already includes CORE coverage checks.

