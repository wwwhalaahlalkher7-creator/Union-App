-- Stage 4 — D1 foundation/reference data and query hardening.
PRAGMA foreign_keys = ON;
ALTER TABLE students ADD COLUMN current_semester_id TEXT REFERENCES semesters(id);
CREATE INDEX IF NOT EXISTS idx_students_department_active ON students(department_id, active);
CREATE INDEX IF NOT EXISTS idx_students_semester ON students(current_semester_id, active);
CREATE INDEX IF NOT EXISTS idx_sessions_student_active ON sessions(student_id, revoked_at, expires_at);
CREATE INDEX IF NOT EXISTS idx_notification_targets_student_read ON notification_targets(student_id, read_at);
CREATE INDEX IF NOT EXISTS idx_reactions_content ON reactions(content_type, content_id, reaction);
CREATE INDEX IF NOT EXISTS idx_comments_student ON comments(student_id, created_at);
CREATE INDEX IF NOT EXISTS idx_material_progress_student_completed ON material_progress(student_id, completed_at);
INSERT OR IGNORE INTO roles (id,name,description) VALUES
('super_admin','Super Admin','صلاحيات كاملة على النظام'),
('content_manager','Content Manager','إدارة الأخبار والأنشطة والإنجازات'),
('academic_manager','Academic Manager','إدارة المواد والجداول والبيانات الأكاديمية'),
('moderator','Moderator','إدارة التعليقات والتفاعلات والمراجعة');
INSERT OR IGNORE INTO departments (id,name_ar,name_en,code,active,sort_order) VALUES
('dep_electronics','كهرباء إلكترونية','Electrical & Electronics','EE',1,1),
('dep_architecture','معمار','Architecture','ARCH',1,2),
('dep_civil','مدنية','Civil Engineering','CE',1,3);
INSERT OR IGNORE INTO semesters (id,name_ar,name_en,academic_year,number,is_current,active) VALUES
('sem_1','الفصل الأول','Semester 1','REFERENCE',1,0,1),
('sem_2','الفصل الثاني','Semester 2','REFERENCE',2,0,1),
('sem_3','الفصل الثالث','Semester 3','REFERENCE',3,0,1),
('sem_4','الفصل الرابع','Semester 4','REFERENCE',4,0,1),
('sem_5','الفصل الخامس','Semester 5','REFERENCE',5,0,1),
('sem_6','الفصل السادس','Semester 6','REFERENCE',6,0,1),
('sem_7','الفصل السابع','Semester 7','REFERENCE',7,0,1),
('sem_8','الفصل الثامن','Semester 8','REFERENCE',8,0,1),
('sem_9','الفصل التاسع','Semester 9','REFERENCE',9,0,1),
('sem_10','الفصل العاشر','Semester 10','REFERENCE',10,0,1);
