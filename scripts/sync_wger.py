#!/usr/bin/env python3
"""Synchronise public wger exercise data into PostgreSQL/Supabase.

Usage:
    python scripts/sync_wger.py
    python scripts/sync_wger.py --dry-run

Required for writes:
    DATABASE_URL=postgresql://...

Optional:
    WGER_BASE_URL=https://wger.de
    WGER_PAGE_SIZE=100
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from typing import Any, Iterator

try:
    import psycopg
    from psycopg.types.json import Jsonb
except ImportError:  # Allows --dry-run to validate API access without DB deps.
    psycopg = None
    Jsonb = None


BASE_URL = os.getenv("WGER_BASE_URL", "https://wger.de").rstrip("/")
API_BASE = f"{BASE_URL}/api/v2"
PAGE_SIZE = int(os.getenv("WGER_PAGE_SIZE", "100"))
USER_AGENT = "RehabApp-WgerSync/1.0 (+https://github.com/Chinchilla6/-)"


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def fetch_json(url: str) -> Any:
    request = urllib.request.Request(
        url,
        headers={"Accept": "application/json", "User-Agent": USER_AGENT},
    )
    with urllib.request.urlopen(request, timeout=45) as response:
        return json.loads(response.read().decode("utf-8"))


def iter_resource(resource: str) -> Iterator[dict[str, Any]]:
    """Yield every object from a paginated DRF resource."""
    url: str | None = f"{API_BASE}/{resource}/?limit={PAGE_SIZE}"
    while url:
        payload = fetch_json(url)
        if isinstance(payload, list):
            for item in payload:
                if isinstance(item, dict):
                    yield item
            return

        for item in payload.get("results", []):
            if isinstance(item, dict):
                yield item

        next_url = payload.get("next")
        if next_url and next_url.startswith("/"):
            next_url = urllib.parse.urljoin(BASE_URL, next_url)
        url = next_url


def as_id(value: Any) -> int | None:
    if isinstance(value, dict):
        value = value.get("id")
    if value in (None, ""):
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def upsert_muscle(cur: Any, muscle: dict[str, Any]) -> None:
    muscle_id = as_id(muscle.get("id"))
    if muscle_id is None:
        return
    cur.execute(
        """
        INSERT INTO wger_muscles
            (id, name, name_en, is_front, image_url_main, image_url_secondary, raw_data, synced_at)
        VALUES (%s, %s, %s, %s, %s, %s, %s, NOW())
        ON CONFLICT (id) DO UPDATE SET
            name = EXCLUDED.name,
            name_en = EXCLUDED.name_en,
            is_front = EXCLUDED.is_front,
            image_url_main = EXCLUDED.image_url_main,
            image_url_secondary = EXCLUDED.image_url_secondary,
            raw_data = EXCLUDED.raw_data,
            synced_at = NOW()
        """,
        (
            muscle_id,
            muscle.get("name") or muscle.get("name_en") or f"muscle-{muscle_id}",
            muscle.get("name_en"),
            muscle.get("is_front"),
            muscle.get("image_url_main"),
            muscle.get("image_url_secondary"),
            Jsonb(muscle),
        ),
    )


def upsert_equipment(cur: Any, equipment: dict[str, Any]) -> None:
    equipment_id = as_id(equipment.get("id"))
    if equipment_id is None:
        return
    cur.execute(
        """
        INSERT INTO wger_equipment (id, name, raw_data, synced_at)
        VALUES (%s, %s, %s, NOW())
        ON CONFLICT (id) DO UPDATE SET
            name = EXCLUDED.name,
            raw_data = EXCLUDED.raw_data,
            synced_at = NOW()
        """,
        (
            equipment_id,
            equipment.get("name") or f"equipment-{equipment_id}",
            Jsonb(equipment),
        ),
    )


def upsert_translation(cur: Any, exercise_id: int, item: dict[str, Any]) -> None:
    translation_id = as_id(item.get("id"))
    name = item.get("name")
    if translation_id is None or not name:
        return
    cur.execute(
        """
        INSERT INTO wger_exercise_translations (
            id, uuid, exercise_id, language_id, name, description, description_source,
            license_id, license_title, license_object_url, license_author,
            license_author_url, license_derivative_source_url, raw_data, synced_at
        ) VALUES (
            %s, %s, %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s, %s, %s, NOW()
        )
        ON CONFLICT (id) DO UPDATE SET
            uuid = EXCLUDED.uuid,
            exercise_id = EXCLUDED.exercise_id,
            language_id = EXCLUDED.language_id,
            name = EXCLUDED.name,
            description = EXCLUDED.description,
            description_source = EXCLUDED.description_source,
            license_id = EXCLUDED.license_id,
            license_title = EXCLUDED.license_title,
            license_object_url = EXCLUDED.license_object_url,
            license_author = EXCLUDED.license_author,
            license_author_url = EXCLUDED.license_author_url,
            license_derivative_source_url = EXCLUDED.license_derivative_source_url,
            raw_data = EXCLUDED.raw_data,
            synced_at = NOW()
        """,
        (
            translation_id,
            item.get("uuid"),
            exercise_id,
            as_id(item.get("language")),
            name,
            item.get("description"),
            item.get("description_source"),
            as_id(item.get("license")),
            item.get("license_title"),
            item.get("license_object_url"),
            item.get("license_author"),
            item.get("license_author_url"),
            item.get("license_derivative_source_url"),
            Jsonb(item),
        ),
    )


def upsert_media(cur: Any, exercise_id: int, media_type: str, item: dict[str, Any]) -> None:
    media_id = as_id(item.get("id"))
    url_key = "image" if media_type == "image" else "video"
    url = item.get(url_key)
    if media_id is None or not url:
        return

    cur.execute(
        """
        INSERT INTO wger_exercise_media (
            media_type, wger_id, uuid, exercise_id, url, is_main, style,
            duration, width, height, codec, license_id, license_title,
            license_object_url, license_author, license_author_url,
            license_derivative_source_url, is_ai_generated, raw_data, synced_at
        ) VALUES (
            %s, %s, %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s, %s, NOW()
        )
        ON CONFLICT (media_type, wger_id) DO UPDATE SET
            uuid = EXCLUDED.uuid,
            exercise_id = EXCLUDED.exercise_id,
            url = EXCLUDED.url,
            is_main = EXCLUDED.is_main,
            style = EXCLUDED.style,
            duration = EXCLUDED.duration,
            width = EXCLUDED.width,
            height = EXCLUDED.height,
            codec = EXCLUDED.codec,
            license_id = EXCLUDED.license_id,
            license_title = EXCLUDED.license_title,
            license_object_url = EXCLUDED.license_object_url,
            license_author = EXCLUDED.license_author,
            license_author_url = EXCLUDED.license_author_url,
            license_derivative_source_url = EXCLUDED.license_derivative_source_url,
            is_ai_generated = EXCLUDED.is_ai_generated,
            raw_data = EXCLUDED.raw_data,
            synced_at = NOW()
        """,
        (
            media_type,
            media_id,
            item.get("uuid"),
            exercise_id,
            url,
            bool(item.get("is_main")),
            item.get("style"),
            item.get("duration"),
            item.get("width"),
            item.get("height"),
            item.get("codec"),
            as_id(item.get("license")),
            item.get("license_title"),
            item.get("license_object_url"),
            item.get("license_author"),
            item.get("license_author_url"),
            item.get("license_derivative_source_url"),
            item.get("is_ai_generated"),
            Jsonb(item),
        ),
    )


def upsert_exercise(cur: Any, exercise: dict[str, Any]) -> bool:
    exercise_id = as_id(exercise.get("id"))
    if exercise_id is None:
        return False

    category = exercise.get("category") or {}
    cur.execute(
        """
        INSERT INTO wger_exercises (
            id, uuid, category_id, category_name, variation_group, license_author,
            created, last_update, last_update_global, raw_data, synced_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW())
        ON CONFLICT (id) DO UPDATE SET
            uuid = EXCLUDED.uuid,
            category_id = EXCLUDED.category_id,
            category_name = EXCLUDED.category_name,
            variation_group = EXCLUDED.variation_group,
            license_author = EXCLUDED.license_author,
            created = EXCLUDED.created,
            last_update = EXCLUDED.last_update,
            last_update_global = EXCLUDED.last_update_global,
            raw_data = EXCLUDED.raw_data,
            synced_at = NOW()
        """,
        (
            exercise_id,
            exercise.get("uuid"),
            as_id(category),
            category.get("name") if isinstance(category, dict) else None,
            as_id(exercise.get("variation_group")),
            exercise.get("license_author"),
            exercise.get("created"),
            exercise.get("last_update"),
            exercise.get("last_update_global"),
            Jsonb(exercise),
        ),
    )

    # Replace relationships for this exercise while keeping app-owned rehab metadata intact.
    cur.execute("DELETE FROM wger_exercise_muscles WHERE exercise_id = %s", (exercise_id,))
    cur.execute("DELETE FROM wger_exercise_equipment WHERE exercise_id = %s", (exercise_id,))

    for role, key in (("primary", "muscles"), ("secondary", "muscles_secondary")):
        for muscle in exercise.get(key) or []:
            if not isinstance(muscle, dict):
                continue
            upsert_muscle(cur, muscle)
            muscle_id = as_id(muscle.get("id"))
            if muscle_id is not None:
                cur.execute(
                    """
                    INSERT INTO wger_exercise_muscles (exercise_id, muscle_id, role)
                    VALUES (%s, %s, %s)
                    ON CONFLICT DO NOTHING
                    """,
                    (exercise_id, muscle_id, role),
                )

    for equipment in exercise.get("equipment") or []:
        if not isinstance(equipment, dict):
            continue
        upsert_equipment(cur, equipment)
        equipment_id = as_id(equipment.get("id"))
        if equipment_id is not None:
            cur.execute(
                """
                INSERT INTO wger_exercise_equipment (exercise_id, equipment_id)
                VALUES (%s, %s)
                ON CONFLICT DO NOTHING
                """,
                (exercise_id, equipment_id),
            )

    for translation in exercise.get("translations") or []:
        if isinstance(translation, dict):
            upsert_translation(cur, exercise_id, translation)

    for image in exercise.get("images") or []:
        if isinstance(image, dict):
            upsert_media(cur, exercise_id, "image", image)

    for video in exercise.get("videos") or []:
        if isinstance(video, dict):
            upsert_media(cur, exercise_id, "video", video)

    return True


def update_sync_state(cur: Any, *, status: str, count: int = 0, error: str | None = None) -> None:
    now = utcnow()
    cur.execute(
        """
        INSERT INTO wger_sync_state
            (resource, last_started_at, last_completed_at, last_status, records_synced, error_message)
        VALUES ('exerciseinfo', %s, %s, %s, %s, %s)
        ON CONFLICT (resource) DO UPDATE SET
            last_started_at = CASE
                WHEN EXCLUDED.last_status = 'running' THEN EXCLUDED.last_started_at
                ELSE wger_sync_state.last_started_at
            END,
            last_completed_at = CASE
                WHEN EXCLUDED.last_status IN ('success', 'error') THEN EXCLUDED.last_completed_at
                ELSE wger_sync_state.last_completed_at
            END,
            last_status = EXCLUDED.last_status,
            records_synced = EXCLUDED.records_synced,
            error_message = EXCLUDED.error_message
        """,
        (now, now if status != "running" else None, status, count, error),
    )


def dry_run() -> int:
    counts: dict[str, int] = {}
    for resource in ("muscle", "equipment"):
        counts[resource] = sum(1 for _ in iter_resource(resource))
    sample = []
    total = 0
    for exercise in iter_resource("exerciseinfo"):
        total += 1
        if len(sample) < 3:
            translations = exercise.get("translations") or []
            sample.append(
                {
                    "id": exercise.get("id"),
                    "uuid": exercise.get("uuid"),
                    "names": [t.get("name") for t in translations[:3] if isinstance(t, dict)],
                    "muscles": len(exercise.get("muscles") or []),
                    "images": len(exercise.get("images") or []),
                    "videos": len(exercise.get("videos") or []),
                }
            )
    counts["exerciseinfo"] = total
    print(json.dumps({"counts": counts, "sample": sample}, ensure_ascii=False, indent=2))
    return 0


def sync() -> int:
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        print("DATABASE_URL is required. Copy .env.example and set your PostgreSQL/Supabase URL.", file=sys.stderr)
        return 2
    if psycopg is None:
        print("Missing psycopg. Run: pip install -r requirements-wger.txt", file=sys.stderr)
        return 2

    count = 0
    try:
        with psycopg.connect(database_url) as conn:
            with conn.cursor() as cur:
                update_sync_state(cur, status="running")
                conn.commit()

                for muscle in iter_resource("muscle"):
                    upsert_muscle(cur, muscle)
                for equipment in iter_resource("equipment"):
                    upsert_equipment(cur, equipment)

                for exercise in iter_resource("exerciseinfo"):
                    if upsert_exercise(cur, exercise):
                        count += 1
                    if count and count % 50 == 0:
                        conn.commit()
                        print(f"Synced {count} exercises...", flush=True)

                update_sync_state(cur, status="success", count=count)
                conn.commit()
        print(f"Done. Synced {count} exercises from {BASE_URL}.")
        return 0
    except Exception as exc:
        # A separate connection makes the failure visible even if the main transaction aborted.
        try:
            if database_url and psycopg is not None:
                with psycopg.connect(database_url) as conn:
                    with conn.cursor() as cur:
                        update_sync_state(cur, status="error", count=count, error=str(exc)[:2000])
                        conn.commit()
        except Exception:
            pass
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync public wger data into the rehab app database")
    parser.add_argument("--dry-run", action="store_true", help="Read wger API and print counts without writing")
    args = parser.parse_args()
    return dry_run() if args.dry_run else sync()


if __name__ == "__main__":
    raise SystemExit(main())
