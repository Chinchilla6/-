-- All synthetic data and approvals are transaction-scoped and rolled back.
BEGIN;
INSERT INTO auth.users(id) VALUES('00000000-0000-0000-0000-000000000097');
DO $$
DECLARE a bigint;b bigint;c bigint;j jsonb;blocked boolean;uid uuid:='00000000-0000-0000-0000-000000000097';
BEGIN
 IF public.exercise_edge_eligible('{"max_rpe":6}',2,1,5,0,7) THEN RAISE EXCEPTION 'RPE condition ignored'; END IF;
 IF public.exercise_edge_eligible('{"unknown":1}',2,1,5,0,7) THEN RAISE EXCEPTION 'Unknown condition ignored'; END IF;
 IF public.exercise_edge_eligible('{"min_quality_score":"bad"}',2,1,5,0,7) THEN RAISE EXCEPTION 'Malformed condition accepted'; END IF;
 IF public.exercise_edge_eligible('{"min_quality_score":4}',2,1,NULL,0,7) THEN RAISE EXCEPTION 'Missing quality accepted'; END IF;
 SELECT id INTO a FROM public.exercise_relationships WHERE from_exercise_id=265 AND to_exercise_id=1642 AND relationship_type='PROGRESSION';
 SELECT id INTO b FROM public.exercise_relationships WHERE from_exercise_id=1642 AND to_exercise_id=294 AND relationship_type='PROGRESSION';
 INSERT INTO public.exercise_relationships(from_exercise_id,to_exercise_id,relationship_type) VALUES(294,265,'PROGRESSION') RETURNING id INTO c;
 IF NOT EXISTS(SELECT 1 FROM public.exercise_graph_validation WHERE issue_type='CIRCULAR_PROGRESSION' AND exercise_id=265) THEN RAISE EXCEPTION 'Three-node cycle not detected'; END IF;
 PERFORM public.review_exercise_relationship(a,'APPROVE',uid);
 PERFORM public.review_exercise_relationship(b,'APPROVE',uid);
 blocked:=false;
 BEGIN PERFORM public.review_exercise_relationship(c,'APPROVE',uid); EXCEPTION WHEN OTHERS THEN blocked:=SQLERRM LIKE '%cycle%'; END;
 IF NOT blocked THEN RAISE EXCEPTION 'Cycle approval allowed'; END IF;
 PERFORM public.review_exercise_relationship(a,'EDIT',uid,'{"required_conditions":{"min_completed_sessions":3,"max_rpe":6}}');
 IF EXISTS(SELECT 1 FROM public.exercise_relationships WHERE id=a AND review_status='REVIEWED') THEN RAISE EXCEPTION 'Edited relation stayed approved'; END IF;
 PERFORM public.review_exercise_relationship(a,'APPROVE',uid);
 INSERT INTO public.exercise_session_feedback(user_id,exercise_id,completed_at,completion,completion_rate,reps,sets,weight,rpe,rir,pain,technique_quality,movement_quality,readiness,fatigue)
 VALUES(uid,265,now()-interval '2 day',true,1,12,4,0,7,3,0,5,5,4,1),(uid,265,now()-interval '1 day',true,1,12,4,0,7,3,0,5,5,4,1);
 j:=public.decide_exercise_progression(265,uid,12,4,0,12,4,'LOAD',false,true);
 IF j->>'decision'<>'KEEP' THEN RAISE EXCEPTION 'Edge-specific conditions ignored: %',j; END IF;
 INSERT INTO public.exercise_session_feedback(user_id,exercise_id,completed_at,completion,completion_rate,rpe,rir,pain,technique_quality,movement_quality,readiness,fatigue) VALUES(uid,265,now(),true,1,5,3,0,5,5,4,1);
 UPDATE public.exercise_session_feedback SET rpe=5 WHERE user_id=uid;
 j:=public.decide_exercise_progression(265,uid,12,4,40,12,4,'LOAD',false,true);
 IF j->>'decision'<>'PROGRESS' OR (j->>'relationship_id')::bigint<>a THEN RAISE EXCEPTION 'Eligible exhausted loaded edge not selected: %',j; END IF;
 UPDATE public.exercise_session_feedback SET pain=5 WHERE user_id=uid AND completed_at=now();
 j:=public.decide_exercise_progression(265,uid,12,4,0,12,4,'LOAD',false,true);
 IF j->>'decision'<>'RECOVERY' THEN RAISE EXCEPTION 'Latest pain averaged away: %',j; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.exercise_relationship_audit WHERE relationship_id=a AND actor_id=uid AND action='UPDATE') THEN RAISE EXCEPTION 'Missing reviewer audit'; END IF;
END $$;
DO $$
DECLARE uid uuid:='00000000-0000-0000-0000-000000000097';rid bigint;j jsonb;
BEGIN
 j:=public.decide_exercise_progression(981,uid);
 IF j->>'decision'<>'KEEP' THEN RAISE EXCEPTION 'No-history fallback failed'; END IF;
 INSERT INTO public.exercise_session_feedback(user_id,exercise_id,completed_at,completion,completion_rate,rpe,rir,pain,technique_quality,movement_quality,readiness,fatigue)
 VALUES(uid,1234,now(),true,1,5,3,0,2,2,4,1),(uid,294,now(),true,1,5,3,0,5,5,4,1);
 j:=public.decide_exercise_progression(1234,uid);
 IF j->>'decision'<>'KEEP' THEN RAISE EXCEPTION 'Pending regression leaked'; END IF;
 SELECT id INTO rid FROM public.exercise_relationships WHERE from_exercise_id=1234 AND to_exercise_id=265 AND relationship_type='REGRESSION';
 PERFORM public.review_exercise_relationship(rid,'APPROVE',uid);
 j:=public.decide_exercise_progression(1234,uid);
 IF j->>'decision'<>'REGRESS' THEN RAISE EXCEPTION 'Reviewed regression not used'; END IF;
 j:=public.decide_exercise_progression(294,uid,12,4,0,12,4,'LOAD',true,true);
 IF j->>'decision'='ALTERNATIVE' THEN RAISE EXCEPTION 'Pending alternative leaked'; END IF;
 SELECT id INTO rid FROM public.exercise_relationships WHERE from_exercise_id=294 AND to_exercise_id=1528 AND relationship_type='ALTERNATIVE';
 PERFORM public.review_exercise_relationship(rid,'APPROVE',uid);
 j:=public.decide_exercise_progression(294,uid,12,4,0,12,4,'LOAD',true,true);
 IF j->>'decision'<>'ALTERNATIVE' THEN RAISE EXCEPTION 'Reviewed alternative not used'; END IF;
 PERFORM public.review_exercise_relationship(rid,'REJECT',uid,'{}'::jsonb,'Test rejection');
 j:=public.decide_exercise_progression(294,uid,12,4,0,12,4,'LOAD',true,true);
 IF j->>'decision'='ALTERNATIVE' THEN RAISE EXCEPTION 'Rejected alternative leaked'; END IF;
END $$;
-- Database access cannot bypass the protected API.
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM public.exercise_relationships WHERE review_status<>'REVIEWED') THEN RAISE EXCEPTION 'Pending relationship RLS leak'; END IF;
 IF EXISTS(SELECT 1 FROM public.exercise_session_feedback) THEN RAISE EXCEPTION 'Other user feedback RLS leak'; END IF;
 IF has_function_privilege('authenticated','public.review_exercise_relationship(bigint,text,uuid,jsonb,text)','EXECUTE') THEN RAISE EXCEPTION 'Authenticated user can review directly'; END IF;
END $$;
RESET ROLE;
ROLLBACK;
SELECT 'PASS: condition gates, multi-node cycles, edit resets, latest pain, load exhaustion, audit, RLS' AS result;

