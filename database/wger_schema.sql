-- wger integration schema for PostgreSQL / Supabase
-- Keeps upstream data separate from app-specific rehabilitation metadata.

CREATE TABLE IF NOT EXISTS wger_muscles (
    id BIGINT PRIMARY KEY,
    name TEXT NOT NULL,
    name_en TEXT,
    is_front BOOLEAN,
    image_url_main TEXT,
    image_url_secondary TEXT,
    raw_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS wger_equipment (
    id BIGINT PRIMARY KEY,
    name TEXT NOT NULL,
    raw_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS wger_exercises (
    id BIGINT PRIMARY KEY,
    uuid UUID UNIQUE,
    category_id BIGINT,
    category_name TEXT,
    variation_group BIGINT,
    license_author TEXT,
    created TIMESTAMPTZ,
    last_update TIMESTAMPTZ,
    last_update_global TIMESTAMPTZ,
    raw_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS wger_exercise_translations (
    id BIGINT PRIMARY KEY,
    uuid UUID UNIQUE,
    exercise_id BIGINT NOT NULL REFERENCES wger_exercises(id) ON DELETE CASCADE,
    language_id BIGINT,
    name TEXT NOT NULL,
    description TEXT,
    description_source TEXT,
    license_id BIGINT,
    license_title TEXT,
    license_object_url TEXT,
    license_author TEXT,
    license_author_url TEXT,
    license_derivative_source_url TEXT,
    raw_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wger_translation_exercise
    ON wger_exercise_translations(exercise_id);
CREATE INDEX IF NOT EXISTS idx_wger_translation_language
    ON wger_exercise_translations(language_id);
CREATE INDEX IF NOT EXISTS idx_wger_translation_name
    ON wger_exercise_translations(name);

CREATE TABLE IF NOT EXISTS wger_exercise_muscles (
    exercise_id BIGINT NOT NULL REFERENCES wger_exercises(id) ON DELETE CASCADE,
    muscle_id BIGINT NOT NULL REFERENCES wger_muscles(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('primary', 'secondary')),
    PRIMARY KEY (exercise_id, muscle_id, role)
);

CREATE INDEX IF NOT EXISTS idx_wger_exercise_muscles_muscle
    ON wger_exercise_muscles(muscle_id, role);

CREATE TABLE IF NOT EXISTS wger_exercise_equipment (
    exercise_id BIGINT NOT NULL REFERENCES wger_exercises(id) ON DELETE CASCADE,
    equipment_id BIGINT NOT NULL REFERENCES wger_equipment(id) ON DELETE CASCADE,
    PRIMARY KEY (exercise_id, equipment_id)
);

CREATE INDEX IF NOT EXISTS idx_wger_exercise_equipment_equipment
    ON wger_exercise_equipment(equipment_id);

CREATE TABLE IF NOT EXISTS wger_exercise_media (
    media_type TEXT NOT NULL CHECK (media_type IN ('image', 'video')),
    wger_id BIGINT NOT NULL,
    uuid UUID,
    exercise_id BIGINT NOT NULL REFERENCES wger_exercises(id) ON DELETE CASCADE,
    url TEXT NOT NULL,
    is_main BOOLEAN NOT NULL DEFAULT FALSE,
    style TEXT,
    duration INTEGER,
    width INTEGER,
    height INTEGER,
    codec TEXT,
    license_id BIGINT,
    license_title TEXT,
    license_object_url TEXT,
    license_author TEXT,
    license_author_url TEXT,
    license_derivative_source_url TEXT,
    is_ai_generated BOOLEAN,
    raw_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (media_type, wger_id)
);

CREATE INDEX IF NOT EXISTS idx_wger_media_exercise
    ON wger_exercise_media(exercise_id, media_type, is_main);

-- App-owned fields. These are intentionally NOT overwritten by wger syncs.
CREATE TABLE IF NOT EXISTS rehab_exercise_metadata (
    exercise_id BIGINT PRIMARY KEY REFERENCES wger_exercises(id) ON DELETE CASCADE,
    name_zh_override TEXT,
    training_types TEXT[] NOT NULL DEFAULT '{}',
    body_regions TEXT[] NOT NULL DEFAULT '{}',
    posture_tags TEXT[] NOT NULL DEFAULT '{}',
    activation_targets TEXT[] NOT NULL DEFAULT '{}',
    release_targets TEXT[] NOT NULL DEFAULT '{}',
    difficulty SMALLINT CHECK (difficulty BETWEEN 1 AND 5),
    recommended_sets_reps JSONB NOT NULL DEFAULT '{}'::jsonb,
    common_mistakes TEXT[] NOT NULL DEFAULT '{}',
    contraindications TEXT[] NOT NULL DEFAULT '{}',
    app_media_url TEXT,
    is_reviewed BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rehab_posture_tags
    ON rehab_exercise_metadata USING GIN(posture_tags);
CREATE INDEX IF NOT EXISTS idx_rehab_body_regions
    ON rehab_exercise_metadata USING GIN(body_regions);
CREATE INDEX IF NOT EXISTS idx_rehab_training_types
    ON rehab_exercise_metadata USING GIN(training_types);

CREATE TABLE IF NOT EXISTS wger_sync_state (
    resource TEXT PRIMARY KEY,
    last_started_at TIMESTAMPTZ,
    last_completed_at TIMESTAMPTZ,
    last_status TEXT,
    records_synced BIGINT NOT NULL DEFAULT 0,
    error_message TEXT
);
