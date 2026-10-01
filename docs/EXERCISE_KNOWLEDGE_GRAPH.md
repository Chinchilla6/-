# Exercise Knowledge Graph · Phase 1

## Principle

Exercise progression is a **reviewed graph, not an inferred ranking**.

Name similarity, embeddings, shared muscles, equipment and difficulty vectors may help generate a candidate, but they never create an approved edge. Every AI-created relationship is inserted as `AUTO_SUGGESTED`. A human admin must explicitly approve it before the runtime engine can read it.

## Existing data reused

The implementation does not replace wger or regenerate exercise IDs.

- `wger_exercises`: canonical exercise IDs and upstream exercise records.
- `wger_exercise_translations`: display names/descriptions; English is language ID 2.
- `wger_exercise_muscles` + `wger_muscles`: primary/secondary muscle facts.
- `wger_exercise_equipment` + `wger_equipment`: equipment facts.
- `rehab_exercise_metadata`: app-owned taxonomy, multidimensional difficulty and rehab content.
- `exercise_progression_rules`: preserved for compatibility, but it contained no production rules when Phase 1 began.
- `evaluate_exercise_progression(...)`: API signature preserved; its implementation now reads only `REVIEWED` graph edges.

At implementation time the live wger sync contained 934 exercises. The previous project count of approximately 861 reflected an older sync; no IDs were changed.

## Exercise classification

Phase 1 classified 60 GLUTE/HIP exercises as `AUTO_SUGGESTED` profiles.

Fields added to `rehab_exercise_metadata`:

- `movement_family`
- `movement_pattern`
- `training_intents`
- `primary_training_intent`
- `strength_demand` 1–5
- `stability_demand` 1–5
- `coordination_demand` 1–5
- `balance_demand` 1–5
- `rom_demand` 1–5
- `mobility_demand` 1–5
- `load_potential` 1–5
- `support_level`
- `laterality`
- `kinetic_chain`
- `equipment_level` 1–5
- `skill_level` 1–5
- `strength_level` 1–5
- `mobility_requirement` 1–5
- classification review/audit fields

Primary and secondary muscles and equipment remain normalized in the existing wger relationship tables and are exposed through `exercise_knowledge_view` rather than duplicated.

Phase 1 patterns include the requested hip/glute patterns plus `SOFT_TISSUE_RELEASE`. The additional pattern exists because foam rolling/release is not truthfully representable as a hip joint movement pattern.

## Relationship graph

`exercise_relationships` supports:

- `PROGRESSION`
- `REGRESSION`
- `ALTERNATIVE`
- `PREPARATION`
- `ACTIVATION`
- `MOBILITY`
- `RELEASE`

Progression dimensions:

- `LOAD`
- `VOLUME`
- `ROM`
- `STABILITY`
- `COORDINATION`
- `BALANCE`
- `UNILATERAL`
- `TEMPO`
- `POWER`
- `ENDURANCE`
- `MOTOR_CONTROL`
- `COMPLEXITY`

Phase 1 seeded 77 candidate edges:

- 28 progression
- 22 regression
- 11 alternative
- 4 preparation
- 4 activation
- 6 mobility
- 2 release

All 77 are `AUTO_SUGGESTED`. No candidate was silently marked `REVIEWED`.

Evidence sources are nullable/empty when no specific source has been attached. The seed does not invent papers.

## Review workflow

The live admin surface is the Supabase Edge Function `progression-admin`.

Path:

`https://nkqoryqioekqhcazwcfz.supabase.co/functions/v1/progression-admin`

The page provides:

- FROM → TO exercise comparison
- movement family/pattern
- primary muscles
- equipment
- multidimensional demand vector
- relationship type and progression dimensions
- AI reason, confidence and evidence level
- APPROVE / REJECT / EDIT
- optional rejection reason
- one-hop graph visualization
- graph validation view

The public GET only serves the login page/UI shell. Every POST API action validates the Supabase bearer token server-side and requires `user.app_metadata.role = 'admin'` (or `is_admin=true`). The service key is never sent to the browser.

At Phase 1 completion the project has no Auth users, so there is intentionally no human reviewer identity yet and therefore zero reviewed relationships. This is not bypassed by the implementation.

## Database review guards

The graph is protected in multiple layers:

1. Self-loops are forbidden by a CHECK constraint.
2. Duplicate `(from, to, relationship_type)` edges are forbidden by a UNIQUE constraint.
3. Missing exercise IDs are blocked by foreign keys.
4. `REVIEWED` requires both `reviewed_by` and `reviewed_at`.
5. AI-created rows must be INSERTed as `AUTO_SUGGESTED` by a trigger.
6. Existing REVIEWED rows cannot be updated/deleted directly. They must pass the explicit review workflow.
7. Editing a relationship resets it to `AUTO_SUGGESTED`, so edited content needs another human approval.
8. `exercise_relationship_audit` records insert/update/delete snapshots.
9. The app-facing RLS policy exposes only `REVIEWED` relationships.
10. `exercise_graph_validation` warns about bidirectional progression cycles and reports GLUTE/HIP exercises without reviewed progression/regression paths.

## User feedback

No production training-history table existed before this phase, so `exercise_session_feedback` was added without changing any existing exercise IDs or data.

It records:

- completion / completion rate
- reps / sets / weight
- RPE / RIR
- pain
- technique quality
- movement quality
- readiness
- fatigue
- goal
- sharp pain
- numbness
- tingling
- radiating pain
- worsening joint pain

RLS allows an authenticated user to access only their own feedback.

## Progression Engine

`decide_exercise_progression(...)` follows this order:

1. Safety block / recovery when red-flag symptoms or meaningful worsening pain are reported.
2. KEEP if there is insufficient history or mastery.
3. REGRESS if technique/movement quality deteriorates or pain rises, but only through a REVIEWED regression edge.
4. ALTERNATIVE when requested, but only through a REVIEWED alternative edge.
5. REPS_UP.
6. LOAD_UP.
7. SETS_UP.
8. KEEP with tempo/ROM adjustment while in-exercise progression is not exhausted.
9. PROGRESS only after the above are exhausted and only via a REVIEWED progression edge.
10. KEEP if no reviewed edge exists.

The engine currently defines mastery as two recent sessions meeting the configured quality/completion reserve rules. These thresholds are product logic, not medical diagnosis, and can be versioned later.

Safety symptoms do not trigger a diagnosis. They block automatic progression and return a recommendation for professional assessment.

## Tests

`database/tests/exercise_knowledge_graph_smoke.sql` verifies:

- pending edges do not leak into the evaluator
- approved edges become visible to the evaluator
- direct mutation of reviewed edges is blocked
- AI cannot insert a pre-reviewed edge
- self-loop / duplicate / missing-ID / missing-reviewer constraints
- decision ordering: REPS_UP → LOAD_UP → SETS_UP → PROGRESS
- sharp-pain safety feedback returns RECOVERY and blocks progression

All temporary approvals and synthetic feedback used in live testing were wrapped in transactions and rolled back.

## CORE next phase

Reuse the same graph schema rather than creating another system.

Suggested CORE patterns:

- `BRACING`
- `ANTI_EXTENSION`
- `ANTI_ROTATION`
- `ANTI_LATERAL_FLEXION`
- `FLEXION`
- `ROTATION`
- `DYNAMIC_STABILITY`

Process:

1. Select a bounded CORE set, roughly 40–80 exercises.
2. Add multidimensional profiles as `AUTO_SUGGESTED`.
3. Generate candidate edges by movement intent and demand-vector change, not by name similarity alone.
4. Human-review the graph in the same Progression Review UI.
5. Add CORE-specific graph validation and engine tests.

Do not expand to all 934 exercises until the GLUTE/HIP review workflow has produced enough reviewed edges to validate the human-review workload and runtime selection behavior.
