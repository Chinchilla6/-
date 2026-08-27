-- Supabase access controls for wger reference data.
-- Client applications may read reference/rehab content, but only server-side
-- database connections should write or run the sync state table.

ALTER TABLE public.wger_muscles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wger_equipment ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wger_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wger_exercise_translations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wger_exercise_muscles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wger_exercise_equipment ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wger_exercise_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rehab_exercise_metadata ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wger_sync_state ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE
  public.wger_muscles,
  public.wger_equipment,
  public.wger_exercises,
  public.wger_exercise_translations,
  public.wger_exercise_muscles,
  public.wger_exercise_equipment,
  public.wger_exercise_media,
  public.rehab_exercise_metadata,
  public.wger_sync_state
FROM anon, authenticated;

GRANT SELECT ON TABLE
  public.wger_muscles,
  public.wger_equipment,
  public.wger_exercises,
  public.wger_exercise_translations,
  public.wger_exercise_muscles,
  public.wger_exercise_equipment,
  public.wger_exercise_media,
  public.rehab_exercise_metadata
TO anon, authenticated;

DROP POLICY IF EXISTS "public_read_wger_muscles" ON public.wger_muscles;
CREATE POLICY "public_read_wger_muscles" ON public.wger_muscles
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "public_read_wger_equipment" ON public.wger_equipment;
CREATE POLICY "public_read_wger_equipment" ON public.wger_equipment
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "public_read_wger_exercises" ON public.wger_exercises;
CREATE POLICY "public_read_wger_exercises" ON public.wger_exercises
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "public_read_wger_translations" ON public.wger_exercise_translations;
CREATE POLICY "public_read_wger_translations" ON public.wger_exercise_translations
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "public_read_wger_exercise_muscles" ON public.wger_exercise_muscles;
CREATE POLICY "public_read_wger_exercise_muscles" ON public.wger_exercise_muscles
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "public_read_wger_exercise_equipment" ON public.wger_exercise_equipment;
CREATE POLICY "public_read_wger_exercise_equipment" ON public.wger_exercise_equipment
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "public_read_wger_media" ON public.wger_exercise_media;
CREATE POLICY "public_read_wger_media" ON public.wger_exercise_media
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "public_read_rehab_metadata" ON public.rehab_exercise_metadata;
CREATE POLICY "public_read_rehab_metadata" ON public.rehab_exercise_metadata
  FOR SELECT TO anon, authenticated USING (true);

-- Intentionally no anon/authenticated policy for wger_sync_state.
REVOKE ALL ON TABLE public.wger_sync_state FROM anon, authenticated;
