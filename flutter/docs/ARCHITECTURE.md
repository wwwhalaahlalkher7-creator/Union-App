# Architecture

The application follows a layered structure:

Presentation → Repository → Data Source → API Client → Cloudflare Worker

Student authentication is isolated under `features/student` and is not required by app startup.
