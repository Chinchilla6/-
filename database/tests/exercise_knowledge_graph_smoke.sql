-- Exercise Knowledge Graph smoke tests.
-- Run on a development database or inside transactions. Tests that temporarily approve
-- an edge explicitly ROLLBACK so no candidate becomes REVIEWED as a side effect.

-- 1) AUTO_SUGGESTED candidates must not leak through the legacy-compatible evaluator.
SELECT count(*) AS leaked_auto_suggested
FROM public.evaluate_exercise_progression(265,'progression',10,1.0,5,0,7);
-- Expected before human review: 0

-- 2) Review workflow exposes a reviewed edge and direct mutation is blocked.
BEGIN;
DO $$
DECLARE rid bigint; blocked boolean:=false;
BEGIN
  SELECT id INTO rid FROM public.exercise_relationships
  WHERE from_exercise_id=265 AND relationship_type='PROGRESSION' ORDER BY id LIMIT 1;
  PERFORM public.review_exercise_relationship(rid,'APPROVE','00000000-0000-0000-0000-000000000001','{}'::jsonb,NULL);
  IF NOT EXISTS(SELECT 1 FROM public.evaluate_exercise_progression(265,'progression',10,1.0,5,0,7)) THEN
    RAISE EXCEPTION 'reviewed relationship was not visible to evaluator';
  END IF;
  BEGIN UPDATE public.exercise_relationships SET notes='unauthorized direct edit' WHERE id=rid;
  EXCEPTION WHEN OTHERS THEN blocked:=true; END;
  IF NOT blocked THEN RAISE EXCEPTION 'direct mutation of REVIEWED relation was not blocked'; END IF;
END $$;
ROLLBACK;

-- 3) AI cannot insert a pre-reviewed edge, even with a reviewer populated.
DO $$
DECLARE blocked boolean:=false;
BEGIN
  BEGIN
    INSERT INTO public.exercise_relationships(from_exercise_id,to_exercise_id,relationship_type,review_status,created_by_type,reviewed_by,reviewed_at)
    VALUES(265,294,'ALTERNATIVE','REVIEWED','AI','00000000-0000-0000-0000-000000000001',now());
  EXCEPTION WHEN OTHERS THEN
    blocked:=position('AI-created exercise relationships must be inserted as AUTO_SUGGESTED' in SQLERRM)>0;
  END;
  IF NOT blocked THEN RAISE EXCEPTION 'AI reviewed insert was not blocked'; END IF;
END $$;

-- 4) Core graph integrity constraints.
DO $$
DECLARE ok_self boolean:=false;ok_dup boolean:=false;ok_missing boolean:=false;ok_reviewer boolean:=false;
BEGIN
  BEGIN INSERT INTO public.exercise_relationships(from_exercise_id,to_exercise_id,relationship_type) VALUES(265,265,'PROGRESSION');
  EXCEPTION WHEN check_violation THEN ok_self:=true; END;
  BEGIN INSERT INTO public.exercise_relationships(from_exercise_id,to_exercise_id,relationship_type) VALUES(265,1642,'PROGRESSION');
  EXCEPTION WHEN unique_violation THEN ok_dup:=true; END;
  BEGIN INSERT INTO public.exercise_relationships(from_exercise_id,to_exercise_id,relationship_type) VALUES(999999999,265,'PROGRESSION');
  EXCEPTION WHEN foreign_key_violation THEN ok_missing:=true; END;
  BEGIN INSERT INTO public.exercise_relationships(from_exercise_id,to_exercise_id,relationship_type,review_status,created_by_type)
    VALUES(265,294,'ALTERNATIVE','REVIEWED','HUMAN');
  EXCEPTION WHEN check_violation THEN ok_reviewer:=true; END;
  IF NOT(ok_self AND ok_dup AND ok_missing AND ok_reviewer) THEN
    RAISE EXCEPTION 'graph constraint test failed self=% dup=% missing=% reviewer=%',ok_self,ok_dup,ok_missing,ok_reviewer;
  END IF;
END $$;

-- 5) Decision-order test with synthetic feedback. No persistent test data is retained.
BEGIN;
SET LOCAL session_replication_role=replica;
INSERT INTO public.exercise_session_feedback(user_id,exercise_id,completed_at,completion,completion_rate,reps,sets,weight,rpe,rir,pain,technique_quality,movement_quality,readiness,fatigue)
VALUES
('00000000-0000-0000-0000-000000000099',265,now()-interval '2 day',true,.98,10,3,40,7,3,1,5,5,4,2),
('00000000-0000-0000-0000-000000000099',265,now()-interval '1 day',true,1,10,3,40,7,3,1,5,5,4,2);
SET LOCAL session_replication_role=origin;
DO $$
DECLARE j jsonb;rid bigint;
BEGIN
  j:=public.decide_exercise_progression(265,'00000000-0000-0000-0000-000000000099',10,3,40,12,4,'LOAD',false,false);
  IF j->>'decision'<>'REPS_UP' THEN RAISE EXCEPTION 'expected REPS_UP, got %',j; END IF;
  j:=public.decide_exercise_progression(265,'00000000-0000-0000-0000-000000000099',12,3,40,12,4,'LOAD',false,false);
  IF j->>'decision'<>'LOAD_UP' THEN RAISE EXCEPTION 'expected LOAD_UP, got %',j; END IF;
  j:=public.decide_exercise_progression(265,'00000000-0000-0000-0000-000000000099',12,3,0,12,4,'LOAD',false,false);
  IF j->>'decision'<>'SETS_UP' THEN RAISE EXCEPTION 'expected SETS_UP, got %',j; END IF;
  SELECT id INTO rid FROM public.exercise_relationships WHERE from_exercise_id=265 AND relationship_type='PROGRESSION' ORDER BY confidence DESC LIMIT 1;
  PERFORM public.review_exercise_relationship(rid,'APPROVE','00000000-0000-0000-0000-000000000001','{}',NULL);
  j:=public.decide_exercise_progression(265,'00000000-0000-0000-0000-000000000099',12,4,0,12,4,'LOAD',false,true);
  IF j->>'decision'<>'PROGRESS' THEN RAISE EXCEPTION 'expected PROGRESS, got %',j; END IF;
END $$;
ROLLBACK;

-- 6) Safety symptom blocks automatic progression.
BEGIN;
SET LOCAL session_replication_role=replica;
INSERT INTO public.exercise_session_feedback(user_id,exercise_id,completed_at,completion,completion_rate,reps,sets,weight,rpe,rir,pain,technique_quality,movement_quality,readiness,fatigue,sharp_pain)
VALUES
('00000000-0000-0000-0000-000000000098',265,now()-interval '2 day',true,1,10,3,40,7,3,1,5,5,4,2,false),
('00000000-0000-0000-0000-000000000098',265,now()-interval '1 day',true,.8,8,2,40,9,0,6,2,2,2,5,true);
SET LOCAL session_replication_role=origin;
DO $$
DECLARE j jsonb;
BEGIN
  j:=public.decide_exercise_progression(265,'00000000-0000-0000-0000-000000000098',10,3,40,12,4,'LOAD',false,false);
  IF j->>'decision'<>'RECOVERY' OR COALESCE((j->>'needs_professional_assessment')::boolean,false)<>true THEN
    RAISE EXCEPTION 'expected RECOVERY safety block, got %',j;
  END IF;
END $$;
ROLLBACK;
