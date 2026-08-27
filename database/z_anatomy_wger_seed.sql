-- Reviewed parent mappings between current wger muscle IDs and Z-Anatomy TA2 codes.
-- Run after TA2 data has been synchronized.

INSERT INTO public.z_anatomy_wger_muscle_map
  (wger_muscle_id, ta2_code, mesh_id, match_type, confidence, notes, is_primary)
VALUES
  (1,'2464',NULL,'manual',1.000,'Biceps brachii muscle',TRUE),
  (2,'2453',NULL,'manual',1.000,'Anterior deltoid mapped to clavicular/anterior part of deltoid',TRUE),
  (3,'2307',NULL,'manual',1.000,'Serratus anterior muscle',TRUE),
  (4,'2301',NULL,'manual',1.000,'Pectoralis major muscle',TRUE),
  (5,'2471',NULL,'manual',1.000,'Triceps brachii muscle',TRUE),
  (6,'2357',NULL,'manual',1.000,'Rectus abdominis muscle',TRUE),
  (7,'2657',NULL,'manual',1.000,'Gastrocnemius muscle',TRUE),
  (8,'2598',NULL,'manual',1.000,'Gluteus maximus muscle',TRUE),
  (9,'2226',NULL,'manual',1.000,'Trapezius muscle',TRUE),
  (10,'2613',NULL,'manual',1.000,'Quadriceps femoris muscle',TRUE),
  (11,'2638',NULL,'manual',1.000,'Biceps femoris muscle',TRUE),
  (12,'2231',NULL,'manual',1.000,'Latissimus dorsi muscle',TRUE),
  (13,'2469',NULL,'manual',1.000,'Brachialis muscle',TRUE),
  (14,'2364',NULL,'manual',1.000,'External abdominal oblique / Musculus obliquus externus abdominis',TRUE),
  (15,'2660',NULL,'manual',1.000,'Soleus muscle',TRUE)
ON CONFLICT (wger_muscle_id, ta2_code, mesh_id) DO UPDATE SET
  match_type = EXCLUDED.match_type,
  confidence = EXCLUDED.confidence,
  notes = EXCLUDED.notes,
  is_primary = EXCLUDED.is_primary;

-- Parent muscle groups whose GLB geometry is split into anatomical child meshes.
WITH rules(wger_muscle_id, pattern) AS (
  VALUES
    (1, 'Long head of biceps brachii%'),
    (1, 'Short head of biceps brachii%'),
    (4, 'Clavicular head of pectoralis major muscle%'),
    (4, 'Sternocostal head of pectoralis major muscle%'),
    (4, '(Abdominal part of pectoralis major muscle)%'),
    (5, 'Long head of triceps brachii%'),
    (5, 'Lateral head of triceps brachii%'),
    (5, 'Medial head of triceps brachii%'),
    (7, 'Lateral head of gastrocnemius%'),
    (7, 'Medial head of gastrocnemius%'),
    (9, 'Descending part of trapezius muscle%'),
    (9, 'Transverse part of trapezius muscle%'),
    (9, 'Ascending part of trapezius muscle%'),
    (10, 'Rectus femoris muscle%'),
    (10, 'Vastus lateralis muscle%'),
    (10, 'Vastus medialis muscle%'),
    (10, 'Vastus intermedius muscle%'),
    (11, 'Long head of biceps femoris%'),
    (11, 'Short head of biceps femoris%')
)
INSERT INTO public.z_anatomy_wger_muscle_map
  (wger_muscle_id, ta2_code, mesh_id, match_type, confidence, notes, is_primary)
SELECT r.wger_muscle_id, m.ta2_code, m.id, 'manual', 1.000,
       'Parent wger muscle group mapped to its anatomical child mesh.', TRUE
FROM rules r
JOIN public.z_anatomy_meshes m
  ON m.anatomical_system = 'muscular' AND m.mesh_name ILIKE r.pattern
WHERE m.ta2_code IS NOT NULL
ON CONFLICT (wger_muscle_id, ta2_code, mesh_id) DO NOTHING;
