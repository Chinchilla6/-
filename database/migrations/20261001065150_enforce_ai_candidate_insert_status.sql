-- AI may generate candidates but may never insert an already-reviewed relationship.
-- Human review happens as a later, explicit state transition.

CREATE OR REPLACE FUNCTION public.enforce_ai_candidate_insert_status()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.created_by_type = 'AI' AND NEW.review_status <> 'AUTO_SUGGESTED' THEN
    RAISE EXCEPTION 'AI-created exercise relationships must be inserted as AUTO_SUGGESTED';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_ai_candidate_insert_status ON public.exercise_relationships;
CREATE TRIGGER trg_enforce_ai_candidate_insert_status
BEFORE INSERT ON public.exercise_relationships
FOR EACH ROW EXECUTE FUNCTION public.enforce_ai_candidate_insert_status();