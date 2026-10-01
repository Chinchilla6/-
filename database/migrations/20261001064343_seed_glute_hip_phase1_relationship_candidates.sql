-- GLUTE + HIP candidate graph.
-- IMPORTANT: every AI-created edge is AUTO_SUGGESTED. This seed does not approve anything.
-- Evidence source is deliberately left empty unless a real DOI/PMID/standard is attached later.

WITH seed(from_id,to_id,rel_type,dims,confidence,evidence_level,reason,conditions) AS (
VALUES
(265,1642,'PROGRESSION',ARRAY['LOAD','ROM']::text[],0.94,'B','Same bilateral hip-extension pattern with added external load.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'::jsonb),
(265,1234,'PROGRESSION',ARRAY['STABILITY','UNILATERAL','COORDINATION'],0.95,'B','Same hip-extension goal with substantially higher unilateral stability demand.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(265,294,'PROGRESSION',ARRAY['LOAD','ROM'],0.92,'B','Same hip-extension family with bench-supported higher-load setup.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(1642,294,'PROGRESSION',ARRAY['LOAD'],0.94,'B','Same hip-thrust pattern with greater barbell load potential.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(990,1131,'PROGRESSION',ARRAY['LOAD'],0.93,'B','Same unilateral hip-extension emphasis with cable resistance.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(990,1616,'PROGRESSION',ARRAY['LOAD','STABILITY'],0.88,'C','Same kickback pattern with added external load and trunk-control demand.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(1842,2665,'PROGRESSION',ARRAY['STABILITY','COORDINATION','ENDURANCE'],0.90,'C','Moves from supported external-rotation activation to loaded locomotor hip control.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(1842,1096,'PROGRESSION',ARRAY['STABILITY','BALANCE'],0.87,'C','Moves from supported hip activation to standing single-leg control.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(1096,2618,'PROGRESSION',ARRAY['COORDINATION','ENDURANCE','COMPLEXITY'],0.86,'C','Adds repeated lateral stepping and locomotor coordination.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(2613,2447,'PROGRESSION',ARRAY['STABILITY','BALANCE','MOTOR_CONTROL','ROM'],0.91,'C','Progresses active hip rotation into single-leg rotational control.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(1578,1392,'PROGRESSION',ARRAY['LOAD','MOTOR_CONTROL'],0.90,'B','Foundational hinge to a loaded posterior-chain hinge pattern.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(1578,1370,'PROGRESSION',ARRAY['LOAD'],0.94,'B','Foundational hinge to externally loaded bilateral deadlift.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(1370,1652,'PROGRESSION',ARRAY['ROM','MOTOR_CONTROL'],0.91,'B','RDL increases controlled posterior-chain ROM under load.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(1652,1688,'PROGRESSION',ARRAY['STABILITY','UNILATERAL','COORDINATION'],0.90,'C','Staggered stance increases asymmetric stability demand.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(1688,1641,'PROGRESSION',ARRAY['UNILATERAL','BALANCE','STABILITY','COORDINATION'],0.95,'B','Moves from kickstand support to true single-leg hinge.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(1578,331,'PROGRESSION',ARRAY['POWER','COMPLEXITY','COORDINATION'],0.88,'B','Ballistic swing adds speed, timing and power to the hinge pattern.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(1312,203,'PROGRESSION',ARRAY['LOAD'],0.95,'B','Same squat pattern with manageable anterior external load.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(203,1640,'PROGRESSION',ARRAY['LOAD','COMPLEXITY'],0.89,'C','Adds load and front-loaded trunk demand.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(1640,257,'PROGRESSION',ARRAY['LOAD','COMPLEXITY'],0.90,'B','Front squat pattern with higher barbell load potential.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(203,1801,'PROGRESSION',ARRAY['LOAD','ROM'],0.88,'C','Progresses goblet squat toward higher-load full barbell squat.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(977,1312,'PROGRESSION',ARRAY['ROM','MOTOR_CONTROL'],0.85,'C','Removes box target and requires self-selected depth/control.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(1948,456,'PROGRESSION',ARRAY['BALANCE','ROM','COMPLEXITY'],0.88,'C','Removes box target and increases unilateral squat ROM/balance demand.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(984,205,'PROGRESSION',ARRAY['LOAD'],0.96,'B','Same lunge pattern with dumbbell load.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(1102,1651,'PROGRESSION',ARRAY['LOAD'],0.96,'B','Same reverse-lunge pattern with dumbbell load.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(984,1366,'PROGRESSION',ARRAY['STABILITY','UNILATERAL','ROM'],0.86,'C','Moves from stepping lunge to stationary split-stance loading.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(1366,1706,'PROGRESSION',ARRAY['ROM','STABILITY','LOAD'],0.94,'B','Rear-foot elevation increases ROM/stability while retaining split-squat pattern.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(981,722,'PROGRESSION',ARRAY['LOAD'],0.97,'B','Same step-up pattern with external load.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),
(1141,2447,'PROGRESSION',ARRAY['MOTOR_CONTROL','ROM','COORDINATION'],0.87,'C','Adds active rotational control to single-leg balance pattern.','{"min_completed_sessions":2,"min_completion_rate":0.95,"min_quality_score":4,"max_pain_score":2,"priority":50}'),

(1642,265,'REGRESSION',ARRAY['LOAD'],0.96,'B','Removes external load while retaining bilateral hip extension.','{}'),
(1234,265,'REGRESSION',ARRAY['UNILATERAL','STABILITY'],0.97,'B','Returns to bilateral supported hip extension.','{}'),
(294,1642,'REGRESSION',ARRAY['LOAD'],0.90,'B','Reduces loading implement while retaining hip-thrust pattern.','{}'),
(1131,990,'REGRESSION',ARRAY['LOAD'],0.94,'B','Removes cable load and returns to low-load activation.','{}'),
(1616,990,'REGRESSION',ARRAY['LOAD','STABILITY'],0.92,'C','Removes external load and simplifies trunk-control demand.','{}'),
(2665,1842,'REGRESSION',ARRAY['COORDINATION','STABILITY'],0.90,'C','Returns from locomotor band work to supported hip activation.','{}'),
(1096,1842,'REGRESSION',ARRAY['BALANCE','STABILITY'],0.88,'C','Removes standing balance demand.','{}'),
(1392,1578,'REGRESSION',ARRAY['LOAD'],0.91,'B','Returns to foundational hinge motor-control drill.','{}'),
(1370,1578,'REGRESSION',ARRAY['LOAD'],0.95,'B','Removes external load while retaining hinge pattern.','{}'),
(1652,1370,'REGRESSION',ARRAY['ROM'],0.88,'C','Reduces hinge ROM emphasis while retaining dumbbell loading.','{}'),
(1688,1652,'REGRESSION',ARRAY['STABILITY','UNILATERAL'],0.92,'C','Returns from staggered to bilateral hinge.','{}'),
(1641,1688,'REGRESSION',ARRAY['BALANCE','UNILATERAL','STABILITY'],0.96,'B','Adds kickstand support to reduce single-leg balance demand.','{}'),
(203,1312,'REGRESSION',ARRAY['LOAD'],0.97,'B','Removes external load while retaining squat pattern.','{}'),
(1640,203,'REGRESSION',ARRAY['LOAD','COMPLEXITY'],0.91,'C','Reduces front-loaded demand to goblet squat.','{}'),
(257,1640,'REGRESSION',ARRAY['LOAD','COMPLEXITY'],0.90,'B','Reduces barbell loading and technical demand.','{}'),
(1801,203,'REGRESSION',ARRAY['LOAD','ROM'],0.86,'C','Reduces external load and can constrain ROM.','{}'),
(456,1948,'REGRESSION',ARRAY['BALANCE','ROM'],0.90,'C','Adds box target and reduces free single-leg squat demand.','{}'),
(205,984,'REGRESSION',ARRAY['LOAD'],0.97,'B','Removes dumbbell load from lunge.','{}'),
(1651,1102,'REGRESSION',ARRAY['LOAD'],0.97,'B','Removes dumbbell load from reverse lunge.','{}'),
(1706,1366,'REGRESSION',ARRAY['ROM','STABILITY'],0.95,'B','Removes rear-foot elevation while retaining split-stance pattern.','{}'),
(722,981,'REGRESSION',ARRAY['LOAD'],0.98,'B','Removes external load from step-up.','{}'),
(2447,1141,'REGRESSION',ARRAY['ROM','MOTOR_CONTROL'],0.85,'C','Simplifies rotational single-leg control.','{}'),

(294,1528,'ALTERNATIVE',ARRAY[]::text[],0.89,'C','Both are loadable bilateral hip-extension strength options with different support/equipment.','{}'),
(1528,294,'ALTERNATIVE',ARRAY[]::text[],0.89,'C','Machine-supported and barbell hip-thrust options can substitute based on equipment/tolerance.','{}'),
(1131,1132,'ALTERNATIVE',ARRAY[]::text[],0.92,'C','Cable and machine hip-extension options target similar intent with different support.','{}'),
(1132,1131,'ALTERNATIVE',ARRAY[]::text[],0.92,'C','Machine and cable hip-extension options target similar intent with different support.','{}'),
(1370,1088,'ALTERNATIVE',ARRAY[]::text[],0.85,'C','Both are loaded bilateral hinge options; stance changes hip/adductor demands.','{}'),
(1088,1612,'ALTERNATIVE',ARRAY[]::text[],0.91,'C','Same sumo-hinge intent with different implement.','{}'),
(1612,1088,'ALTERNATIVE',ARRAY[]::text[],0.91,'C','Same sumo-hinge intent with different implement.','{}'),
(984,1102,'ALTERNATIVE',ARRAY[]::text[],0.90,'C','Forward/standard and reverse lunge variants can substitute depending on control/tolerance.','{}'),
(205,1651,'ALTERNATIVE',ARRAY[]::text[],0.90,'C','Loaded forward/standing and reverse lunge variants can substitute.','{}'),
(257,1801,'ALTERNATIVE',ARRAY[]::text[],0.82,'C','Both are loadable squat patterns with different bar position and demands.','{}'),
(981,984,'ALTERNATIVE',ARRAY[]::text[],0.78,'C','Step-up and lunge are unilateral lower-body alternatives, not linear equivalents.','{}'),

(294,265,'ACTIVATION',ARRAY[]::text[],0.93,'C','Use low-load bridge as a glute activation option before heavy hip thrusting.','{}'),
(294,1842,'ACTIVATION',ARRAY[]::text[],0.82,'C','External-rotation activation can be used when frontal/transverse hip control is a preparation goal.','{}'),
(1801,1842,'ACTIVATION',ARRAY[]::text[],0.76,'C','Hip activation option before squatting when indicated by coaching goal.','{}'),
(984,2665,'ACTIVATION',ARRAY[]::text[],0.78,'C','Banded lateral work can prepare frontal-plane hip control before lunges.','{}'),

(294,1867,'MOBILITY',ARRAY[]::text[],0.83,'C','Hip-flexor mobility may be useful preparation when extension ROM is limited.','{}'),
(1801,2613,'MOBILITY',ARRAY[]::text[],0.86,'C','90/90 switches can prepare hip rotation before squatting.','{}'),
(1801,1867,'MOBILITY',ARRAY[]::text[],0.78,'C','Hip-flexor mobility option before squat work when relevant.','{}'),
(1407,1844,'MOBILITY',ARRAY[]::text[],0.91,'C','Frog stretch addresses high adductor mobility demands of Cossack squat.','{}'),
(1407,2614,'MOBILITY',ARRAY[]::text[],0.94,'C','Adductor rock-back directly prepares adductor ROM for Cossack squat.','{}'),
(1706,2525,'MOBILITY',ARRAY[]::text[],0.87,'C','Couch stretch can prepare hip extension/quad mobility for rear-foot-elevated split squat.','{}'),

(2447,2613,'PREPARATION',ARRAY[]::text[],0.94,'C','90/90 active rotation is a lower-balance preparation for hip airplane.','{}'),
(1641,1578,'PREPARATION',ARRAY[]::text[],0.95,'B','Bilateral hinge patterning is a preparation drill for single-leg hinge.','{}'),
(331,1578,'PREPARATION',ARRAY[]::text[],0.96,'B','Hip-hinge patterning prepares the movement strategy before ballistic swings.','{}'),
(456,1862,'PREPARATION',ARRAY[]::text[],0.75,'C','Dynamic hip circles can be used as general preparation before high-ROM single-leg squatting.','{}'),

(294,1859,'RELEASE',ARRAY[]::text[],0.80,'C','Glute foam rolling may be used as optional recovery/release, not as a required progression step.','{}'),
(1407,1860,'RELEASE',ARRAY[]::text[],0.82,'C','Adductor foam rolling may be used as optional release/recovery around high adductor-demand work.','{}')
)
INSERT INTO public.exercise_relationships(
 from_exercise_id,to_exercise_id,relationship_type,progression_dimension,difficulty_delta,
 required_conditions,confidence,evidence_level,evidence_source,review_status,ai_reason,created_by_type,notes)
SELECT s.from_id,s.to_id,s.rel_type,s.dims,
 jsonb_build_object(
  'strength',COALESCE(t.strength_demand,0)-COALESCE(f.strength_demand,0),
  'stability',COALESCE(t.stability_demand,0)-COALESCE(f.stability_demand,0),
  'coordination',COALESCE(t.coordination_demand,0)-COALESCE(f.coordination_demand,0),
  'balance',COALESCE(t.balance_demand,0)-COALESCE(f.balance_demand,0),
  'rom',COALESCE(t.rom_demand,0)-COALESCE(f.rom_demand,0),
  'mobility',COALESCE(t.mobility_demand,0)-COALESCE(f.mobility_demand,0),
  'load_potential',COALESCE(t.load_potential,0)-COALESCE(f.load_potential,0)),
 s.conditions,s.confidence,s.evidence_level,'{}'::text[],'AUTO_SUGGESTED',s.reason,'AI',
 'Phase 1 GLUTE/HIP candidate; requires human review.'
FROM seed s
JOIN public.rehab_exercise_metadata f ON f.exercise_id=s.from_id
JOIN public.rehab_exercise_metadata t ON t.exercise_id=s.to_id
ON CONFLICT(from_exercise_id,to_exercise_id,relationship_type) DO UPDATE SET
 progression_dimension=EXCLUDED.progression_dimension,difficulty_delta=EXCLUDED.difficulty_delta,
 required_conditions=EXCLUDED.required_conditions,confidence=EXCLUDED.confidence,evidence_level=EXCLUDED.evidence_level,
 ai_reason=EXCLUDED.ai_reason,notes=EXCLUDED.notes,updated_at=now()
WHERE public.exercise_relationships.review_status='AUTO_SUGGESTED';