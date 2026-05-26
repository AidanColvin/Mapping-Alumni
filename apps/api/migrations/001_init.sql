CREATE TABLE IF NOT EXISTS institutions (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  country TEXT,
  wikidata_id TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS companies (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  slug TEXT,
  sector TEXT,
  domain TEXT
);

CREATE TABLE IF NOT EXISTS people (
  id TEXT PRIMARY KEY,
  full_name TEXT NOT NULL,
  source_url TEXT NOT NULL,
  source_type TEXT NOT NULL,
  retrieved_at TEXT NOT NULL,
  confidence REAL DEFAULT 0.5
);

CREATE TABLE IF NOT EXISTS employment_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  person_id TEXT REFERENCES people(id),
  company_id TEXT REFERENCES companies(id),
  title TEXT,
  title_level TEXT,
  sector TEXT,
  is_current INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS education_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  person_id TEXT REFERENCES people(id),
  institution_id TEXT REFERENCES institutions(id),
  start_year INTEGER,
  end_year INTEGER
);

CREATE TABLE IF NOT EXISTS source_documents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  url TEXT NOT NULL,
  source_type TEXT NOT NULL,
  retrieved_at TEXT NOT NULL,
  person_id TEXT REFERENCES people(id)
);

CREATE INDEX IF NOT EXISTS idx_inst_slug ON institutions(slug);
CREATE INDEX IF NOT EXISTS idx_people_name ON people(full_name);
