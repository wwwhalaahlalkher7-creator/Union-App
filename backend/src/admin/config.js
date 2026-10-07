// Central admin configuration. Keep authorization and resource metadata out of request handlers.
export const ADMIN_ROLE_PERMISSIONS = Object.freeze({
  super_admin: ['*'],
  content_manager: ['content.read', 'content.write', 'dashboard.read'],
  academic_manager: ['academic.read', 'academic.write', 'dashboard.read'],
  moderator: ['moderation.read', 'moderation.write', 'notifications.read', 'notifications.write', 'dashboard.read'],
});
export const ADMIN_ROLE_IDS = new Set(Object.keys(ADMIN_ROLE_PERMISSIONS));

export const ADMIN_FIELDS = {
  news: ['title','body','image_url','images_json','publish_at','expires_at','status','category','publisher'],
  announcements: ['title','body','type','target_department_id','target_semester_id','publish_at','expires_at','status'],
  events: ['title','body','image_url','images_json','category','event_at','end_at','location','publisher','status'],
  achievements: ['title','description','intro','highlights_title','highlights','badge','publisher','image_url','images_json','achieved_at','status'],
  subjects: ['semester_id','department_id','code','name_ar','name_en','active','sort_order'],
  materials: ['subject_id','title','description','drive_file_id','drive_url','mime_type','size_bytes','active','sort_order','drive_parent_id','drive_modified_at','drive_web_view_url','pinned','source'],
  schedules: ['semester_id','department_id','subject_id','day_of_week','start_time','end_time','room','lecturer','active'],
  students: ['student_number','full_name','email','department_id','current_semester_id','active'],
  comments: ['student_id','content_type','content_id','body','status'],
};

export const CONTENT_STATUS_VALUES = Object.freeze(new Set(['draft', 'published']));
export const CONTENT_TABLES = Object.freeze(new Set(['news', 'events', 'announcements', 'achievements']));
export const CONTENT_UPDATED_BY_TABLES = Object.freeze(new Set(['news', 'events', 'achievements']));


export const ADMIN_SELECT_COLUMNS = {
  news: 'id,title,body,image_url,images_json,publish_at,expires_at,status,category,publisher,created_by,updated_by,created_at,updated_at',
  announcements: 'id,title,body,type,target_department_id,target_semester_id,publish_at,expires_at,status,created_by,created_at,updated_at',
  events: 'id,title,body,image_url,images_json,category,event_at,end_at,location,publisher,status,created_by,updated_by,created_at,updated_at',
  achievements: 'id,title,description,intro,highlights_title,highlights,badge,publisher,image_url,images_json,achieved_at,status,created_by,updated_by,created_at,updated_at',
  subjects: 'id,semester_id,department_id,code,name_ar,name_en,active,sort_order',
  materials: 'id,subject_id,title,description,drive_file_id,drive_url,mime_type,size_bytes,active,sort_order,drive_parent_id,drive_modified_at,drive_web_view_url,pinned,source,created_at,updated_at',
  schedules: 'id,semester_id,department_id,subject_id,day_of_week,start_time,end_time,room,lecturer,active,created_by,updated_by,updated_at',
  students: 'id,student_number,full_name,email,department_id,current_semester_id,active,CASE WHEN auth_secret_hash IS NULL THEN 0 ELSE 1 END AS registered,created_at,updated_at',
  comments: 'id,student_id,content_type,content_id,body,status,created_at,updated_at',
};
