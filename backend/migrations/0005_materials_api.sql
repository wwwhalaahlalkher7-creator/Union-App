-- Stage 7 — Materials API/query foundation.
PRAGMA foreign_keys = ON;

CREATE INDEX IF NOT EXISTS idx_materials_subject_pinned_sort
  ON materials(subject_id, active, pinned DESC, sort_order, title);

CREATE INDEX IF NOT EXISTS idx_subjects_department_semester_sort
  ON subjects(department_id, semester_id, active, sort_order, name_ar);

CREATE INDEX IF NOT EXISTS idx_progress_student_material
  ON material_progress(student_id, material_id);
