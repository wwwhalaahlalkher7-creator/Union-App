# Admin UI migration

The public website no longer ships a web administration panel. All administrative UI is maintained in the separate Flutter project `TRINEX-Admin`.

The web build excludes `website/admin`, the website Worker returns 404 for `/admin` paths, and the main-branch deployment workflow cleans only the remote `/htdocs/admin/` directory before deploying public website files. Backend/API deployment and database migrations are unchanged by this migration.
