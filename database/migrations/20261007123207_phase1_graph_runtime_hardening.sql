-- Additive Phase 1 hardening; no canonical IDs or feedback rows are changed.
-- Unknown conditions and contraindications require supported context before runtime use.
CREATE OR REPLACE FUNCTION public.exercise_edge_eligible(c jsonb,n integer,completion numeric,quality numeric,pain numeric,rpe numeric)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path=public AS $$
DECLARE k text; v numeric;
BEGIN
 IF jsonb_typeof(c)<>'object' OR c IS NULL THEN RETURN false; END IF;
 FOR k IN SELECT jsonb_object_keys(c) LOOP
  IF k NOT IN('min_completed_sessions','min_completion_rate','min_quality_score','max_pain_score','max_rpe','priority') THEN RETURN false; END IF;
  IF jsonb_typeof(c->k)<>'number' THEN RETURN false; END IF;
  v:=(c->>k)::numeric;
  IF (k='min_completed_sessions' AND (v<0 OR v<>trunc(v))) OR (k='min_completion_rate' AND v NOT BETWEEN 0 AND 1)
   OR (k='min_quality_score' AND v NOT BETWEEN 1 AND 5) OR (k IN('max_pain_score','max_rpe') AND v NOT BETWEEN 0 AND 10)
   OR (k='priority' AND (v<0 OR v>32767 OR v<>trunc(v))) THEN RETURN false; END IF;
 END LOOP;
 RETURN (NOT(c?'min_completed_sessions') OR (n IS NOT NULL AND n>=(c->>'min_completed_sessions')::numeric))
 AND (NOT(c?'min_completion_rate') OR (completion IS NOT NULL AND completion>=(c->>'min_completion_rate')::numeric))
 AND (NOT(c?'min_quality_score') OR (quality IS NOT NULL AND quality>=(c->>'min_quality_score')::numeric))
 AND (NOT(c?'max_pain_score') OR (pain IS NOT NULL AND pain<=(c->>'max_pain_score')::numeric))
 AND (NOT(c?'max_rpe') OR (rpe IS NOT NULL AND rpe<=(c->>'max_rpe')::numeric));
END $$;

-- UNION deduplicates reachable pairs so arbitrary-length cycles terminate.
CREATE OR REPLACE VIEW public.exercise_graph_validation WITH(security_invoker=true) AS
WITH RECURSIVE active AS (SELECT * FROM public.exercise_relationships WHERE relationship_type='PROGRESSION' AND review_status IN('AUTO_SUGGESTED','REVIEWED')),
reach(root,node) AS (SELECT from_exercise_id,to_exercise_id FROM active UNION SELECT r.root,e.to_exercise_id FROM reach r JOIN active e ON e.from_exercise_id=r.node)
SELECT 'CIRCULAR_PROGRESSION'::text issue_type,NULL::bigint relationship_id,root exercise_id,jsonb_build_object('cycle_member',root) details FROM reach WHERE root=node
UNION ALL
SELECT 'NO_REVIEWED_PROGRESSION',NULL::bigint,r.exercise_id,jsonb_build_object('family',r.movement_family,'pattern',r.movement_pattern)
FROM public.rehab_exercise_metadata r WHERE r.movement_family IN('GLUTE','HIP','CORE') AND r.primary_training_intent IN('STRENGTH','HYPERTROPHY','MOTOR_CONTROL','ACTIVATION','BALANCE','POWER')
AND r.classification_status<>'REJECTED' AND NOT EXISTS(SELECT 1 FROM public.exercise_relationships e WHERE e.from_exercise_id=r.exercise_id AND e.relationship_type='PROGRESSION' AND e.review_status='REVIEWED')
UNION ALL
SELECT 'NO_REVIEWED_REGRESSION',NULL::bigint,r.exercise_id,jsonb_build_object('family',r.movement_family,'pattern',r.movement_pattern)
FROM public.rehab_exercise_metadata r WHERE r.movement_family IN('GLUTE','HIP','CORE') AND r.primary_training_intent IN('STRENGTH','HYPERTROPHY','MOTOR_CONTROL','ACTIVATION','BALANCE','POWER')
AND r.classification_status<>'REJECTED' AND NOT EXISTS(SELECT 1 FROM public.exercise_relationships e WHERE e.from_exercise_id=r.exercise_id AND e.relationship_type='REGRESSION' AND e.review_status='REVIEWED')
UNION ALL
SELECT 'MISSING_EVIDENCE_SOURCE',id,from_exercise_id,jsonb_build_object('evidence_level',evidence_level,'status',review_status)
FROM public.exercise_relationships WHERE review_status<>'REJECTED' AND evidence_level IS NOT NULL AND cardinality(evidence_source)=0
UNION ALL
SELECT 'UNSUPPORTED_CONDITIONS',id,from_exercise_id,jsonb_build_object('conditions',required_conditions)
FROM public.exercise_relationships WHERE review_status<>'REJECTED' AND NOT public.exercise_edge_eligible(required_conditions,2147483647,1,5,0,0);
REVOKE ALL ON public.exercise_graph_validation FROM anon,authenticated;

CREATE OR REPLACE FUNCTION public.guard_review_transition()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=public AS $$
BEGIN
 IF NEW.review_status='REVIEWED' AND (OLD.review_status IS DISTINCT FROM NEW.review_status OR NEW.relationship_type='PROGRESSION') THEN
  IF COALESCE(current_setting('app.relationship_review_edit',true),'')<>'on' THEN RAISE EXCEPTION 'Approval requires explicit review workflow'; END IF;
  IF NOT public.exercise_edge_eligible(NEW.required_conditions,2147483647,1,5,0,0) THEN RAISE EXCEPTION 'Unsupported or malformed required conditions'; END IF;
  IF NEW.relationship_type='PROGRESSION' AND EXISTS(
   WITH RECURSIVE reach(node) AS (
    SELECT NEW.to_exercise_id UNION SELECT e.to_exercise_id FROM public.exercise_relationships e JOIN reach r ON e.from_exercise_id=r.node
    WHERE e.review_status='REVIEWED' AND e.relationship_type='PROGRESSION' AND e.id<>NEW.id)
   SELECT 1 FROM reach WHERE node=NEW.from_exercise_id
  ) THEN RAISE EXCEPTION 'Approval would create a progression cycle'; END IF;
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER trg_guard_review_transition BEFORE UPDATE ON public.exercise_relationships FOR EACH ROW EXECUTE FUNCTION public.guard_review_transition();
-- Serialize reviews: two simultaneous approvals must not jointly introduce a cycle.
CREATE OR REPLACE FUNCTION public.serialize_graph_review() RETURNS trigger LANGUAGE plpgsql SET search_path=public AS $$
BEGIN PERFORM pg_advisory_xact_lock(706107); RETURN NULL; END $$;
CREATE TRIGGER trg_serialize_graph_review BEFORE UPDATE ON public.exercise_relationships FOR EACH STATEMENT EXECUTE FUNCTION public.serialize_graph_review();

CREATE OR REPLACE FUNCTION public.evaluate_exercise_progression(p_exercise_id bigint,p_direction text,p_completed_sessions integer DEFAULT 0,p_completion_rate numeric DEFAULT NULL,p_quality_score numeric DEFAULT NULL,p_pain_score numeric DEFAULT NULL,p_rpe numeric DEFAULT NULL)
RETURNS TABLE(rule_id bigint,next_exercise_id bigint,direction text,priority smallint,criteria_text text,rationale_text text,evidence_claim_id bigint)
LANGUAGE sql STABLE SET search_path=public AS $$
SELECT r.id,r.to_exercise_id,lower(r.relationship_type),COALESCE((r.required_conditions->>'priority')::smallint,50::smallint),r.required_conditions::text,COALESCE(r.notes,r.ai_reason),NULL::bigint
FROM public.exercise_relationships r WHERE r.from_exercise_id=p_exercise_id AND r.relationship_type=upper(p_direction)
 AND upper(p_direction) IN('PROGRESSION','REGRESSION') AND r.review_status='REVIEWED'
 AND public.exercise_edge_eligible(r.required_conditions,p_completed_sessions,p_completion_rate,p_quality_score,p_pain_score,p_rpe)
 AND cardinality(r.contraindications)=0
 AND NOT EXISTS(SELECT 1 FROM public.rehab_exercise_metadata m WHERE m.exercise_id=r.to_exercise_id AND m.classification_status='REJECTED')
ORDER BY COALESCE((r.required_conditions->>'priority')::int,50),r.confidence DESC NULLS LAST,r.id; $$;


CREATE OR REPLACE FUNCTION public.decide_exercise_progression(
 p_exercise_id bigint,p_user_id uuid DEFAULT NULL,p_current_reps integer DEFAULT NULL,p_current_sets integer DEFAULT NULL,
 p_current_weight numeric DEFAULT NULL,p_target_rep_max integer DEFAULT NULL,p_target_set_max integer DEFAULT NULL,
 p_goal text DEFAULT NULL,p_need_alternative boolean DEFAULT false,p_in_exercise_progression_exhausted boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=public AS $$
DECLARE v_uid uuid:=COALESCE(p_user_id,auth.uid());v_total int;v_count int;v_good int;v_completion numeric;v_rpe numeric;v_rir numeric;v_pain numeric;v_tech numeric;v_move numeric;v_readiness numeric;v_fatigue numeric;v_safety boolean;v_edge public.exercise_relationships;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'user is required'; END IF;
 IF auth.uid() IS NOT NULL AND v_uid<>auth.uid() THEN RAISE EXCEPTION 'cannot evaluate another user'; END IF;
 SELECT count(*) INTO v_total FROM public.exercise_session_feedback WHERE user_id=v_uid AND exercise_id=p_exercise_id AND completion=true AND completed_at<=now();
 WITH recent AS(SELECT * FROM public.exercise_session_feedback WHERE user_id=v_uid AND exercise_id=p_exercise_id AND completed_at<=now() ORDER BY completed_at DESC,id DESC LIMIT 2)
 SELECT count(*),count(*) FILTER(WHERE completion=true AND completion_rate>=.95 AND COALESCE(rir,0)>=2 AND COALESCE(rpe,10)<=8 AND COALESCE(pain,10)<=2 AND COALESCE(technique_quality,0)>=4 AND COALESCE(movement_quality,0)>=4 AND COALESCE(readiness,0)>=3),
 avg(completion_rate),avg(rpe),avg(rir),max(pain),min(technique_quality),min(movement_quality),min(readiness),max(fatigue),bool_or(sharp_pain OR numbness OR tingling OR radiating_pain OR joint_pain_worsening)
 INTO v_count,v_good,v_completion,v_rpe,v_rir,v_pain,v_tech,v_move,v_readiness,v_fatigue,v_safety FROM recent;
 IF COALESCE(v_safety,false) OR COALESCE(v_pain,0)>=4 THEN RETURN jsonb_build_object('decision','RECOVERY','reason','Safety symptom or worsening pain blocks automatic progression','next_exercise_id',NULL,'needs_professional_assessment',true); END IF;
 IF v_count=0 THEN RETURN jsonb_build_object('decision','KEEP','reason','No recent exercise history','next_exercise_id',NULL); END IF;
 IF COALESCE(v_readiness,5)<=2 OR COALESCE(v_fatigue,1)>=4.5 THEN RETURN jsonb_build_object('decision','RECOVERY','reason','Low readiness or high fatigue','next_exercise_id',NULL); END IF;
 IF COALESCE(v_tech,5)<3 OR COALESCE(v_move,5)<3 OR COALESCE(v_pain,0)>2 THEN
  SELECT * INTO v_edge FROM public.exercise_relationships WHERE from_exercise_id=p_exercise_id AND relationship_type='REGRESSION' AND review_status='REVIEWED' AND public.exercise_edge_eligible(required_conditions,v_total,v_completion,LEAST(v_tech,v_move),v_pain,v_rpe) AND cardinality(contraindications)=0 AND NOT EXISTS(SELECT 1 FROM public.rehab_exercise_metadata m WHERE m.exercise_id=to_exercise_id AND m.classification_status='REJECTED') ORDER BY confidence DESC NULLS LAST,id LIMIT 1;
  IF v_edge.id IS NOT NULL THEN RETURN jsonb_build_object('decision','REGRESS','reason','Technique/movement quality or pain indicates a reviewed regression','next_exercise_id',v_edge.to_exercise_id,'relationship_id',v_edge.id); END IF;
  RETURN jsonb_build_object('decision','KEEP','reason','Technique or pain needs improvement; no reviewed regression is available','next_exercise_id',NULL);
 END IF;
 IF p_need_alternative THEN
  SELECT * INTO v_edge FROM public.exercise_relationships WHERE from_exercise_id=p_exercise_id AND relationship_type='ALTERNATIVE' AND review_status='REVIEWED' AND public.exercise_edge_eligible(required_conditions,v_total,v_completion,LEAST(v_tech,v_move),v_pain,v_rpe) AND cardinality(contraindications)=0 AND NOT EXISTS(SELECT 1 FROM public.rehab_exercise_metadata m WHERE m.exercise_id=to_exercise_id AND m.classification_status='REJECTED') ORDER BY confidence DESC NULLS LAST,id LIMIT 1;
  IF v_edge.id IS NOT NULL THEN RETURN jsonb_build_object('decision','ALTERNATIVE','reason','A reviewed alternative was requested','next_exercise_id',v_edge.to_exercise_id,'relationship_id',v_edge.id); END IF;
 END IF;
 IF v_good<2 THEN RETURN jsonb_build_object('decision','KEEP','reason','Current exercise has not yet met mastery criteria for two consecutive sessions','next_exercise_id',NULL); END IF;
 IF p_current_reps IS NOT NULL AND p_target_rep_max IS NOT NULL AND p_current_reps<p_target_rep_max THEN RETURN jsonb_build_object('decision','REPS_UP','reason','Mastery criteria met; increase repetitions before changing exercise','suggested_reps',p_current_reps+1,'next_exercise_id',NULL); END IF;
 IF NOT p_in_exercise_progression_exhausted AND COALESCE(p_current_weight,0)>0 AND COALESCE(v_rir,0)>=2 AND COALESCE(v_rpe,10)<=8 THEN RETURN jsonb_build_object('decision','LOAD_UP','reason','Mastery criteria met with reserve available; increase load before changing exercise','next_exercise_id',NULL); END IF;
 IF p_current_sets IS NOT NULL AND p_target_set_max IS NOT NULL AND p_current_sets<p_target_set_max THEN RETURN jsonb_build_object('decision','SETS_UP','reason','Mastery criteria met; increase volume before changing exercise','suggested_sets',p_current_sets+1,'next_exercise_id',NULL); END IF;
 IF NOT p_in_exercise_progression_exhausted THEN RETURN jsonb_build_object('decision','KEEP','reason','Use tempo or ROM progression before changing exercise; graph progression is not yet unlocked','adjustment','TEMPO_OR_ROM','next_exercise_id',NULL); END IF;
 SELECT * INTO v_edge FROM public.exercise_relationships WHERE from_exercise_id=p_exercise_id AND relationship_type='PROGRESSION' AND review_status='REVIEWED' AND public.exercise_edge_eligible(required_conditions,v_total,v_completion,LEAST(v_tech,v_move),v_pain,v_rpe) AND cardinality(contraindications)=0 AND NOT EXISTS(SELECT 1 FROM public.rehab_exercise_metadata m WHERE m.exercise_id=to_exercise_id AND m.classification_status='REJECTED')
 ORDER BY CASE WHEN p_goal IS NOT NULL AND p_goal=ANY(progression_dimension) THEN 0 ELSE 1 END,confidence DESC NULLS LAST,id LIMIT 1;
 IF v_edge.id IS NOT NULL THEN RETURN jsonb_build_object('decision','PROGRESS','reason','In-exercise progression exhausted; selected from REVIEWED exercise graph','next_exercise_id',v_edge.to_exercise_id,'relationship_id',v_edge.id,'dimensions',v_edge.progression_dimension); END IF;
 RETURN jsonb_build_object('decision','KEEP','reason','No REVIEWED progression edge is available','next_exercise_id',NULL);
END; $$;
REVOKE ALL ON FUNCTION public.decide_exercise_progression(bigint,uuid,integer,integer,numeric,integer,integer,text,boolean,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.decide_exercise_progression(bigint,uuid,integer,integer,numeric,integer,integer,text,boolean,boolean) TO authenticated,service_role;

