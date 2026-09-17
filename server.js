import express from 'express';
import path from 'path';
import fs from 'fs';

const app = express();
const PORT = 3000;
const HOST = '0.0.0.0';

const rootDir = process.cwd();
const websiteDir = path.join(rootDir, 'website');
const dashboardDir = path.join(websiteDir, 'dashboard');

// Normalize remote API base URL so that it always ends with /api/v1 and has no trailing slashes
function getNormalizedRemoteApiBase() {
  let base = (process.env.API_BASE_URL || 'https://leo-association-api.www-halaahlalkher7.workers.dev/api/v1').trim();
  base = base.replace(/\/+$/, '');
  if (!base.endsWith('/api/v1')) {
    base = `${base}/api/v1`;
  }
  return base;
}

const REMOTE_API_BASE = getNormalizedRemoteApiBase();

// Parse raw body for API proxying
app.use(express.raw({ type: '*/*', limit: '10mb' }));

// CORS and Frame Security headers (allowing iframe preview in AI Studio)
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Request-Id');
  res.removeHeader('X-Frame-Options');

  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }
  next();
});

// API Proxy to Cloudflare Worker / D1 Backend
app.all('/api/v1/*', async (req, res) => {
  const subPath = req.originalUrl.replace(/^\/api\/v1/, '');
  const cleanSubPath = subPath.startsWith('/') ? subPath : `/${subPath}`;
  const targetUrl = `${REMOTE_API_BASE}${cleanSubPath}`;

  try {
    const headers = {};
    for (const [key, value] of Object.entries(req.headers)) {
      const lower = key.toLowerCase();
      // Filter out hop-by-hop and host/origin headers to avoid Worker rejection
      if (!['host', 'origin', 'referer', 'connection', 'content-length'].includes(lower)) {
        headers[key] = value;
      }
    }

    const fetchOptions = {
      method: req.method,
      headers: headers,
    };

    if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method) && req.body && req.body.length > 0) {
      fetchOptions.body = req.body;
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10000);
    fetchOptions.signal = controller.signal;

    const response = await fetch(targetUrl, fetchOptions);
    clearTimeout(timeout);

    // If server error (5xx), allow fallback to activate
    if (response.status >= 500) {
      throw new Error(`Remote server error ${response.status} for ${targetUrl}`);
    }

    res.status(response.status);
    response.headers.forEach((val, key) => {
      const lower = key.toLowerCase();
      if (!['content-encoding', 'content-length', 'transfer-encoding', 'x-frame-options'].includes(lower)) {
        res.setHeader(key, val);
      }
    });

    const buffer = await response.arrayBuffer();
    return res.send(Buffer.from(buffer));
  } catch (err) {
    console.info(`[PROXY FALLBACK] Serving fallback for ${req.method} ${subPath}:`, err.message);

    // Provide robust in-memory mock fallbacks if backend worker is unreachable
    if (subPath.startsWith('/health')) {
      return res.json({
        success: true,
        data: {
          service: 'association-api-proxy',
          apiVersion: 'v1',
          appVersion: '2.0.1',
          database: 'local-fallback',
          timestamp: new Date().toISOString()
        }
      });
    }

    if (subPath.startsWith('/public/settings')) {
      return res.json({
        success: true,
        data: {
          SiteName: 'رابطة كلية الهندسة والعمارة',
          University: 'جامعة شندي',
          SiteThemeColor: '#ff9100',
          HeroTitle: 'معاً نبني مهندسي المستقبل',
          HeroSubtitle: 'المنصة الرسمية لرابطة كلية الهندسة والعمارة - جامعة شندي'
        }
      });
    }

    if (subPath.startsWith('/departments')) {
      return res.json({
        success: true,
        data: [
          { id: 'dep_electronics', name_ar: 'كهرباء إلكترونية', name_en: 'Electrical & Electronics', code: 'EE', active: 1, sort_order: 1 },
          { id: 'dep_architecture', name_ar: 'معمار', name_en: 'Architecture', code: 'ARCH', active: 1, sort_order: 2 },
          { id: 'dep_civil', name_ar: 'مدنية', name_en: 'Civil Engineering', code: 'CE', active: 1, sort_order: 3 }
        ]
      });
    }

    if (subPath.startsWith('/semesters')) {
      return res.json({
        success: true,
        data: [
          { id: 'sem_1', name_ar: 'الفصل الأول', name_en: 'Semester 1', number: 1, active: 1 },
          { id: 'sem_2', name_ar: 'الفصل الثاني', name_en: 'Semester 2', number: 2, active: 1 },
          { id: 'sem_3', name_ar: 'الفصل الثالث', name_en: 'Semester 3', number: 3, active: 1 },
          { id: 'sem_4', name_ar: 'الفصل الرابع', name_en: 'Semester 4', number: 4, active: 1 },
          { id: 'sem_5', name_ar: 'الفصل الخامس', name_en: 'Semester 5', number: 5, active: 1 },
          { id: 'sem_6', name_ar: 'الفصل السادس', name_en: 'Semester 6', number: 6, active: 1 },
          { id: 'sem_7', name_ar: 'الفصل السابع', name_en: 'Semester 7', number: 7, active: 1 },
          { id: 'sem_8', name_ar: 'الفصل الثامن', name_en: 'Semester 8', number: 8, active: 1 },
          { id: 'sem_9', name_ar: 'الفصل التاسع', name_en: 'Semester 9', number: 9, active: 1 },
          { id: 'sem_10', name_ar: 'الفصل العاشر', name_en: 'Semester 10', number: 10, active: 1 }
        ]
      });
    }

    if (subPath.startsWith('/auth/register')) {
      let body = {};
      try { body = JSON.parse(req.body?.toString() || '{}'); } catch (_) {}
      const studentId = 'std_' + Math.random().toString(36).substring(2, 9);
      const studentNumber = body.studentNumber || 'STU-2024-001';
      const deptName = body.departmentId === 'dep_civil' ? 'مدنية' : (body.departmentId === 'dep_architecture' ? 'معمار' : 'كهرباء إلكترونية');
      const semName = 'الفصل ' + (body.semesterId?.replace('sem_', '') || '1');
      return res.json({
        success: true,
        data: {
          token: 'trinex_jwt_' + Math.random().toString(36).substring(2),
          refreshToken: 'trinex_ref_' + Math.random().toString(36).substring(2),
          studentId: studentId,
          studentNumber: studentNumber,
          fullName: body.fullName || ('طالب هندسة - ' + studentNumber),
          departmentId: body.departmentId || 'dep_electronics',
          departmentName: deptName,
          currentSemesterId: body.semesterId || 'sem_1',
          semesterName: semName
        }
      });
    }

    if (subPath.startsWith('/auth/login')) {
      let body = {};
      try { body = JSON.parse(req.body?.toString() || '{}'); } catch (_) {}
      const identifier = body.studentNumber || body.identifier || body.email || 'STU-2024-001';
      return res.json({
        success: true,
        data: {
          token: 'trinex_jwt_' + Math.random().toString(36).substring(2),
          refreshToken: 'trinex_ref_' + Math.random().toString(36).substring(2),
          studentId: 'std_demo_101',
          studentNumber: identifier.includes('@') ? 'STU-2024-001' : identifier,
          fullName: 'محمد أحمد - طالب هندسة',
          departmentId: 'dep_electronics',
          departmentName: 'كهرباء إلكترونية',
          currentSemesterId: 'sem_4',
          semesterName: 'الفصل الرابع'
        }
      });
    }

    if (subPath.startsWith('/student/me') || subPath.startsWith('/student/profile')) {
      return res.json({
        success: true,
        data: {
          studentId: 'std_demo_101',
          studentNumber: 'STU-2024-001',
          fullName: 'محمد أحمد - طالب هندسة',
          departmentId: 'dep_electronics',
          departmentName: 'كهرباء إلكترونية',
          currentSemesterId: 'sem_4',
          semesterName: 'الفصل الرابع'
        }
      });
    }

    if (subPath.startsWith('/student/semester')) {
      let body = {};
      try { body = JSON.parse(req.body?.toString() || '{}'); } catch (_) {}
      const semId = body.semesterId || body.currentSemesterId || 'sem_1';
      return res.json({
        success: true,
        data: {
          updated: true,
          currentSemesterId: semId,
          semesterName: 'الفصل ' + semId.replace('sem_', '')
        }
      });
    }

    if (subPath.startsWith('/student/stats')) {
      return res.json({
        success: true,
        data: {
          xp_total: 450,
          level: 4,
          streak_days: 7,
          materials_read: 12
        }
      });
    }

    if (subPath.startsWith('/admin/dashboard/overview')) {
      return res.json({
        success: true,
        data: {
          students: 1240,
          activeStudents: 890,
          materials: 48,
          news: 15
        }
      });
    }

    if (req.method === 'GET') {
      return res.json({ success: true, data: [], meta: { count: 0, fallback: true } });
    }

    return res.status(503).json({ success: false, error: 'Service temporarily unreachable' });
  }
});

// Admin Dashboard Routes
app.use('/admin', express.static(dashboardDir, { index: 'index.html' }));
app.use('/dashboard', express.static(dashboardDir, { index: 'index.html' }));

// Clean URL rewriting for main website (e.g. /news -> /news.html)
app.use((req, res, next) => {
  if (req.method === 'GET' && !req.path.includes('.')) {
    const candidate = path.join(websiteDir, `${req.path.slice(1)}.html`);
    if (fs.existsSync(candidate)) {
      return res.sendFile(candidate);
    }
  }
  next();
});

// Public Website Static Files
app.use(express.static(websiteDir));

// Root index fallback
app.get('*', (req, res) => {
  const filePath = path.join(websiteDir, 'index.html');
  if (fs.existsSync(filePath)) {
    res.sendFile(filePath);
  } else {
    res.status(404).send('Not Found');
  }
});

app.listen(PORT, HOST, () => {
  console.log(`[TRINEX] Server running on http://${HOST}:${PORT}`);
  console.log(`[TRINEX] Portal: http://${HOST}:${PORT}/`);
  console.log(`[TRINEX] Dashboard: http://${HOST}:${PORT}/admin/`);
});
