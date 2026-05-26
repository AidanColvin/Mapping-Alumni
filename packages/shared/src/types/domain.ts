/**
 * Domain types that mirror the Python API models exactly.
 * Source of truth: apps/api/app/models/domain.py
 */

export type TitleLevel =
  | "c_suite"
  | "founder"
  | "vp"
  | "director"
  | "manager"
  | "individual"
  | "unknown";

export type SourceType =
  | "wikidata"
  | "wikipedia"
  | "company_site"
  | "sec_filing"
  | "university_page";

export interface Institution {
  id: string;
  name: string;
  slug: string;
  aliases: string[];
  country: string | null;
  wikidata_id: string | null;
}

export interface Company {
  id: string;
  name: string;
  slug: string;
  sector: string | null;
  domain: string | null;
}

export interface Employment {
  company: Company | null;
  title: string;
  title_level: TitleLevel;
  sector: string;
  is_current: boolean;
}

export interface Person {
  id: string;
  full_name: string;
  source_url: string;
  source_type: SourceType;
  retrieved_at: string;
  confidence: number;
  verified_fields: string[];
}

export interface SearchResult {
  person: Person;
  employment: Employment[];
  institution: Institution | null;
}

export interface SearchResponse {
  results: SearchResult[];
  total: number;
  page: number;
  limit: number;
  institution: Institution | null;
}

export interface UniversityResponse {
  institution: Institution;
  alumni_count: number;
  top_employers: Array<{ company: string; count: number }>;
  sector_breakdown: Record<string, number>;
  title_level_breakdown: Record<string, number>;
}

export interface SearchFilters {
  university: string;
  sector?: string;
  title_level?: TitleLevel;
  company_type?: string;
  region?: string;
  keyword?: string;
  page?: number;
  limit?: number;
}
