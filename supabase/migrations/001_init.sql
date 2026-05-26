-- Institutions
CREATE TABLE institutions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  aliases TEXT[] DEFAULT '{}',
  country TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Companies
CREATE TABLE companies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT,
  domain TEXT,
  sector TEXT,
  company_type TEXT
);

-- Company domains
CREATE TABLE company_domains (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id),
  domain TEXT NOT NULL
);

-- People
CREATE TABLE people (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name TEXT NOT NULL,
  slug TEXT,
  source_url TEXT NOT NULL,
  source_type TEXT NOT NULL,
  retrieved_at TIMESTAMPTZ NOT NULL,
  confidence FLOAT DEFAULT 0.5,
  verified_fields TEXT[] DEFAULT '{}'
);

-- Education history
CREATE TABLE education_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  person_id UUID REFERENCES people(id),
  institution_id UUID REFERENCES institutions(id),
  degree TEXT,
  field TEXT,
  start_year INT,
  end_year INT
);

-- Employment history
CREATE TABLE employment_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  person_id UUID REFERENCES people(id),
  company_id UUID REFERENCES companies(id),
  title TEXT,
  title_level TEXT,
  sector TEXT,
  start_year INT,
  end_year INT,
  is_current BOOLEAN DEFAULT FALSE
);

-- Source documents
CREATE TABLE source_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  url TEXT NOT NULL,
  source_type TEXT NOT NULL,
  retrieved_at TIMESTAMPTZ NOT NULL,
  person_id UUID REFERENCES people(id)
);

-- Search jobs
CREATE TABLE search_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  query JSONB NOT NULL,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT now(),
  completed_at TIMESTAMPTZ
);

-- Result snapshots
CREATE TABLE result_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  search_job_id UUID REFERENCES search_jobs(id),
  results JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);
