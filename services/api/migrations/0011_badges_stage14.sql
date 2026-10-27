PRAGMA foreign_keys = ON;
CREATE INDEX IF NOT EXISTS idx_badges_active_sort ON badges(active, sort_order, id);
CREATE INDEX IF NOT EXISTS idx_student_badges_badge_awarded ON student_badges(badge_id, awarded_at DESC);
INSERT OR IGNORE INTO badges (id,name_ar,description_ar,icon_url,rule_type,rule_value,active,sort_order) VALUES
('badge-first-step','البداية','ابدأ أول تقدم دراسي موثق.',NULL,'progress_events',1,1,10),
('badge-first-complete','أول إنجاز','أكمل أول ملف دراسي.',NULL,'completed_materials',1,1,20),
('badge-five-complete','خمسة ملفات','أكمل 5 ملفات دراسية.',NULL,'completed_materials',5,1,30),
('badge-ten-complete','عشرة ملفات','أكمل 10 ملفات دراسية.',NULL,'completed_materials',10,1,40),
('badge-level-5','المستوى 5','وصل إلى المستوى الخامس.',NULL,'level',5,1,50),
('badge-500-xp','500 XP','اجمع 500 XP من أنشطتك الدراسية.',NULL,'xp_total',500,1,60);
