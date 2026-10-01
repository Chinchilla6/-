-- Review workflow hardening.
-- The explicit review override must be reset inside the same transaction so later SQL
-- cannot mutate a REVIEWED edge without re-entering the review workflow.

CREATE OR REPLACE FUNCTION public.review_exercise_relationship(
  p_relationship_id bigint,
  p_action text,
  p_reviewer uuid,
  p_patch jsonb DEFAULT '{}'::jsonb,
  p_rejection_reason text DEFAULT NULL
)
RETURNS public.exercise_relationships
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_row public.exercise_relationships;
  v_action text := upper(p_action);
BEGIN
  IF p_reviewer IS NULL THEN RAISE EXCEPTION 'reviewer is required'; END IF;
  IF v_action NOT IN ('APPROVE','REJECT','EDIT') THEN RAISE EXCEPTION 'unsupported review action: %', p_action; END IF;

  PERFORM set_config('app.relationship_review_edit', 'on', true);
  PERFORM set_config('app.relationship_actor', p_reviewer::text, true);

  IF v_action = 'APPROVE' THEN
    UPDATE public.exercise_relationships
    SET review_status='REVIEWED', reviewed_by=p_reviewer, reviewed_at=now(), rejection_reason=NULL
    WHERE id=p_relationship_id RETURNING * INTO v_row;
  ELSIF v_action = 'REJECT' THEN
    UPDATE public.exercise_relationships
    SET review_status='REJECTED', reviewed_by=p_reviewer, reviewed_at=now(), rejection_reason=p_rejection_reason
    WHERE id=p_relationship_id RETURNING * INTO v_row;
  ELSE
    UPDATE public.exercise_relationships
    SET relationship_type=COALESCE(p_patch->>'relationship_type',relationship_type),
        progression_dimension=CASE WHEN p_patch?'progression_dimension' THEN ARRAY(SELECT jsonb_array_elements_text(p_patch->'progression_dimension')) ELSE progression_dimension END,
        difficulty_delta=CASE WHEN p_patch?'difficulty_delta' THEN p_patch->'difficulty_delta' ELSE difficulty_delta END,
        required_conditions=CASE WHEN p_patch?'required_conditions' THEN p_patch->'required_conditions' ELSE required_conditions END,
        contraindications=CASE WHEN p_patch?'contraindications' THEN ARRAY(SELECT jsonb_array_elements_text(p_patch->'contraindications')) ELSE contraindications END,
        confidence=COALESCE((p_patch->>'confidence')::numeric,confidence),
        evidence_level=CASE WHEN p_patch?'evidence_level' THEN NULLIF(p_patch->>'evidence_level','') ELSE evidence_level END,
        evidence_source=CASE WHEN p_patch?'evidence_source' THEN ARRAY(SELECT jsonb_array_elements_text(p_patch->'evidence_source')) ELSE evidence_source END,
        ai_reason=COALESCE(p_patch->>'ai_reason',ai_reason),
        notes=CASE WHEN p_patch?'notes' THEN p_patch->>'notes' ELSE notes END,
        review_status='AUTO_SUGGESTED', reviewed_by=NULL, reviewed_at=NULL, rejection_reason=NULL
    WHERE id=p_relationship_id RETURNING * INTO v_row;
  END IF;

  PERFORM set_config('app.relationship_review_edit', 'off', true);
  PERFORM set_config('app.relationship_actor', '', true);

  IF v_row.id IS NULL THEN RAISE EXCEPTION 'relationship not found'; END IF;
  RETURN v_row;
END;
$$;

REVOKE ALL ON FUNCTION public.review_exercise_relationship(bigint,text,uuid,jsonb,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.review_exercise_relationship(bigint,text,uuid,jsonb,text) TO service_role;