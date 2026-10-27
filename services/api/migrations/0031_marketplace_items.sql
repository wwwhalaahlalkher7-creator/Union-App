-- Real, dashboard-managed engineering marketplace catalog.
CREATE TABLE IF NOT EXISTS market_items (
  id TEXT PRIMARY KEY,
  title_ar TEXT NOT NULL,
  title_en TEXT,
  description_ar TEXT NOT NULL,
  description_en TEXT,
  category TEXT NOT NULL DEFAULT 'engineering',
  price_label TEXT,
  image_url TEXT,
  contact_url TEXT,
  department_id TEXT REFERENCES departments(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published')),
  active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_by TEXT,
  updated_by TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_market_items_public_order
  ON market_items(active, status, sort_order, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_market_items_department
  ON market_items(department_id, active, status);
