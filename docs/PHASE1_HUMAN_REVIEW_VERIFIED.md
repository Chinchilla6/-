# Phase 1 human review verification — 2026-10-07

This checkpoint supersedes earlier zero-reviewed counts in the initial acceptance report.

## Live results

All 77 relationships are REVIEWED; AUTO_SUGGESTED count is zero. Distribution: PROGRESSION 28, REGRESSION 22, ALTERNATIVE 11, PREPARATION 4, ACTIVATION 4, MOBILITY 6, RELEASE 2. Exactly one reviewer identity is recorded. Every reviewed relationship has reviewed_by and reviewed_at.

Graph validation reports no progression cycles or unsupported conditions. The legacy-compatible evaluator returns three eligible reviewed progression edges for exercise 265 with a sufficiently completed-session count and qualifying feedback.

A transaction-scoped integration test inserted a synthetic user and two qualifying feedback records, called decide_exercise_progression with in-exercise progression exhausted, and asserted that PROGRESS selected an existing REVIEWED relationship with the matching target exercise. The test passed. All synthetic user/feedback data were rolled back; no production review status was changed.

## Hosting and login

GitHub Pages publishing succeeded and the user completed the admin review workflow. Supabase Site URL and the exact redirect allowlist entry were changed from the localhost default/empty list to https://chinchilla6.github.io/-/progression-review/. Direct email verification remains available as a fallback. Email sending is limited to two emails per hour under the current project configuration.

## Remaining coverage and evidence work

All 77 relations still lack attached evidence_source entries despite provisional B/C evidence labels. A human relationship review does not establish source-backed evidence grading by itself. Attach and verify specific sources; editing an approved edge resets it to AUTO_SUGGESTED and requires another explicit human approval.

Validation reports 27 profiles without a reviewed outgoing progression and 24 without a reviewed outgoing regression. Classify legitimate starting/terminal exercises explicitly during the next coverage pass rather than inventing edges merely to clear warnings. Propose genuinely missing edges only as candidates for human review.

Next phase: complete the evidence/coverage pass, then expand CORE using the existing schema, review API and engine. Do not automatically approve CORE candidates.
