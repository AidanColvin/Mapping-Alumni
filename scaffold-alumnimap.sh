#!/bin/bash
set -e

echo "Scaffolding AlumniMap..."
mkdir -p alumnimap
cd alumnimap

# ── Root config ────────────────────────────────────────────────────────────────

cat > package.json << 'EOF'
{
  "name": "alumnimap",
  "private": true,
  "workspaces": ["apps/*", "packages/*"],
  "scripts": {
    "dev:web": "npm run dev --workspace=apps/web",
    "dev:api": "npm run dev --workspace=apps/api",
    "build": "npm run build --workspaces",
    "test": "npm run test --workspaces --if-present"
  }
}
EOF

cat > .gitignore << 'EOF'
node_modules
.next
dist
.env
.env.local
.env*.local
.vercel
*.log
EOF

cat > .env.local << 'EOF'
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
EOF

# ── packages/shared ────────────────────────────────────────────────────────────

mkdir -p packages/shared/src/{types,schemas,constants,utils}

cat > packages/shared/package.json << 'EOF'
{
  "name": "@alumnimap/shared",
  "version": "0.0.1",
  "main": "src/index.ts"
}
EOF

cat > packages/shared/src/types/domain.ts << 'EOF'
export interface Institution {
  id: string;
  name: string;
  slug: string;
  aliases: string[];
  country: string;
  created_at: string;
}

export interface Person {
  id: string;
  full_name: string;
  slug: string;
  source_url: string;
  source_type: string;
  retrieved_at: string;
  confidence: number;
  verified_fields: string[];
}

export interface EducationHistory {
  id: string;
  person_id: string;
  institution_id: string;
  degree?: string;
  field?: string;
  start_year?: number;
  end_year?: number;
}

export interface EmploymentHistory {
  id: string;
  person_id: string;
  company_id: string;
  title: string;
  title_level: TitleLevel;
  sector: string;
  start_year?: number;
  end_year?: number | null;
  is_current: boolean;
}

export interface Company {
  id: string;
  name: string;
  slug: string;
  domain?: string;
  sector?: string;
  company_type?: string;
}

export interface SourceDocument {
  id: string;
  url: string;
  source_type: string;
  retrieved_at: string;
  person_id?: string;
}

export type TitleLevel =
  | "c_suite"
  | "founder"
  | "vp"
  | "director"
  | "manager"
  | "individual"
  | "unknown";

export interface SearchResult {
  person: Person;
  employment: EmploymentHistory[];
  education: EducationHistory[];
  company?: Company;
}

export interface SearchFilters {
  university: string;
  sector?: string;
  title_level?: TitleLevel;
  company_type?: string;
  region?: string;
}
EOF

cat > packages/shared/src/schemas/search.ts << 'EOF'
import { z } from "zod";

export const SearchInputSchema = z.object({
  university: z.string().min(2).max(120),
  sector: z.string().optional(),
  title_level: z
    .enum(["c_suite", "founder", "vp", "director", "manager", "individual", "unknown"])
    .optional(),
  company_type: z.string().optional(),
  region: z.string().optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

export type SearchInput = z.infer<typeof SearchInputSchema>;

export const UniversityInputSchema = z.object({
  query: z.string().min(2).max(120),
});

export type UniversityInput = z.infer<typeof UniversityInputSchema>;
EOF

cat > packages/shared/src/constants/index.ts << 'EOF'
export const TITLE_LEVELS = [
  "c_suite",
  "founder",
  "vp",
  "director",
  "manager",
  "individual",
  "unknown",
] as const;

export const SECTORS = [
  "technology",
  "finance",
  "healthcare",
  "government",
  "education",
  "media",
  "nonprofit",
  "consulting",
  "legal",
  "other",
] as const;

export const SOURCE_TYPES = [
  "wikidata",
  "company_site",
  "sec_filing",
  "university_page",
  "public_profile",
] as const;

export const CACHE_TTL_SECONDS = 60 * 60 * 6; // 6 hours
export const MAX_RESULTS_PER_PAGE = 50;
EOF

cat > packages/shared/src/utils/index.ts << 'EOF'
export function slugify(text: string): string {
  return text
    .toLowerCase()
    .trim()
    .replace(/[\s_]+/g, "-")
    .replace(/[^a-z0-9-]/g, "")
    .replace(/-+/g, "-");
}

export function normalize(text: string): string {
  return text.toLowerCase().trim().replace(/\s+/g, " ");
}

export function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}
EOF

cat > packages/shared/src/index.ts << 'EOF'
export * from "./types/domain";
export * from "./schemas/search";
export * from "./constants";
export * from "./utils";
EOF

# ── apps/web ───────────────────────────────────────────────────────────────────

mkdir -p apps/web/{app/{search,"university/[slug]"},components,lib,styles}

cat > apps/web/package.json << 'EOF'
{
  "name": "@alumnimap/web",
  "version": "0.0.1",
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start"
  },
  "dependencies": {
    "next": "14.2.3",
    "react": "^18",
    "react-dom": "^18",
    "@supabase/supabase-js": "^2",
    "zod": "^3",
    "@alumnimap/shared": "*"
  },
  "devDependencies": {
    "typescript": "^5",
    "@types/react": "^18",
    "@types/node": "^20",
    "tailwindcss": "^3",
    "autoprefixer": "^10",
    "postcss": "^8"
  }
}
EOF

cat > apps/web/app/layout.tsx << 'EOF'
import type { Metadata } from "next";
import "../styles/globals.css";

export const metadata: Metadata = {
  title: "AlumniMap",
  description: "Discover where university alumni work and lead.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="bg-gray-50 text-gray-900 min-h-screen">{children}</body>
    </html>
  );
}
EOF

cat > apps/web/app/page.tsx << 'EOF'
import SearchBar from "../components/search-bar";

export default function Home() {
  return (
    <main className="flex flex-col items-center justify-center min-h-screen gap-8 px-4">
      <h1 className="text-4xl font-bold tracking-tight">AlumniMap</h1>
      <p className="text-gray-500 text-lg">
        Discover where alumni from any university work and lead.
      </p>
      <SearchBar />
    </main>
  );
}
EOF

cat > apps/web/app/search/page.tsx << 'EOF'
import { SearchInputSchema } from "@alumnimap/shared";
import FilterPanel from "../../components/filter-panel";
import ResultsGrid from "../../components/results-grid";

interface Props {
  searchParams: Record<string, string>;
}

export default async function SearchPage({ searchParams }: Props) {
  const parsed = SearchInputSchema.safeParse(searchParams);

  if (!parsed.success) {
    return <p className="p-8 text-red-500">Invalid search parameters.</p>;
  }

  const params = new URLSearchParams(
    Object.entries(parsed.data).map(([k, v]) => [k, String(v)])
  );

  const res = await fetch(
    `${process.env.NEXT_PUBLIC_API_URL}/api/search?${params}`,
    { next: { revalidate: 3600 } }
  );

  const data = res.ok ? await res.json() : { results: [] };

  return (
    <div className="max-w-5xl mx-auto px-4 py-10">
      <FilterPanel filters={parsed.data} />
      <ResultsGrid results={data.results} />
    </div>
  );
}
EOF

cat > "apps/web/app/university/[slug]/page.tsx" << 'EOF'
interface Props {
  params: { slug: string };
  searchParams: Record<string, string>;
}

export default async function UniversityPage({ params, searchParams }: Props) {
  const res = await fetch(
    `${process.env.NEXT_PUBLIC_API_URL}/api/universities/${params.slug}`,
    { next: { revalidate: 3600 } }
  );

  if (!res.ok) return <p className="p-8">University not found.</p>;

  const data = await res.json();

  return (
    <div className="max-w-5xl mx-auto px-4 py-10">
      <h1 className="text-3xl font-bold mb-2">{data.institution?.name}</h1>
      <p className="text-gray-500 mb-8">Alumni in the AlumniMap index</p>
      {/* ResultsGrid and filters rendered here */}
    </div>
  );
}
EOF

cat > apps/web/components/search-bar.tsx << 'EOF'
"use client";
import { useRouter } from "next/navigation";
import { useState } from "react";

export default function SearchBar() {
  const router = useRouter();
  const [value, setValue] = useState("");

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!value.trim()) return;
    router.push(`/search?university=${encodeURIComponent(value.trim())}`);
  }

  return (
    <form onSubmit={handleSubmit} className="flex gap-2 w-full max-w-lg">
      <input
        type="text"
        value={value}
        onChange={(e) => setValue(e.target.value)}
        placeholder="Enter a university name..."
        className="flex-1 border border-gray-300 rounded-lg px-4 py-2 text-base focus:outline-none focus:ring-2 focus:ring-blue-500"
      />
      <button
        type="submit"
        className="bg-blue-600 text-white px-5 py-2 rounded-lg font-medium hover:bg-blue-700"
      >
        Search
      </button>
    </form>
  );
}
EOF

cat > apps/web/components/filter-panel.tsx << 'EOF'
"use client";
import { useRouter, useSearchParams } from "next/navigation";
import { SECTORS, TITLE_LEVELS } from "@alumnimap/shared";

interface Props {
  filters: Record<string, unknown>;
}

export default function FilterPanel({ filters }: Props) {
  const router = useRouter();
  const params = useSearchParams();

  function update(key: string, value: string) {
    const next = new URLSearchParams(params.toString());
    value ? next.set(key, value) : next.delete(key);
    router.push(`/search?${next.toString()}`);
  }

  return (
    <div className="flex flex-wrap gap-4 mb-6">
      <select
        defaultValue={(filters.sector as string) ?? ""}
        onChange={(e) => update("sector", e.target.value)}
        className="border rounded px-3 py-1.5 text-sm"
      >
        <option value="">All sectors</option>
        {SECTORS.map((s) => (
          <option key={s} value={s}>
            {s}
          </option>
        ))}
      </select>
      <select
        defaultValue={(filters.title_level as string) ?? ""}
        onChange={(e) => update("title_level", e.target.value)}
        className="border rounded px-3 py-1.5 text-sm"
      >
        <option value="">All levels</option>
        {TITLE_LEVELS.map((t) => (
          <option key={t} value={t}>
            {t.replace("_", " ")}
          </option>
        ))}
      </select>
    </div>
  );
}
EOF

cat > apps/web/components/results-grid.tsx << 'EOF'
import type { SearchResult } from "@alumnimap/shared";
import AlumniCard from "./alumni-card";
import EmptyState from "./empty-state";

interface Props {
  results: SearchResult[];
}

export default function ResultsGrid({ results }: Props) {
  if (!results?.length) return <EmptyState />;
  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
      {results.map((r) => (
        <AlumniCard key={r.person.id} result={r} />
      ))}
    </div>
  );
}
EOF

cat > apps/web/components/alumni-card.tsx << 'EOF'
import type { SearchResult } from "@alumnimap/shared";
import SourceLink from "./source-link";
import StatsChip from "./stats-chip";

interface Props {
  result: SearchResult;
}

export default function AlumniCard({ result }: Props) {
  const { person, employment } = result;
  const current = employment.find((e) => e.is_current);

  return (
    <div className="border border-gray-200 rounded-xl p-4 bg-white shadow-sm flex flex-col gap-2">
      <p className="font-semibold text-base">{person.full_name}</p>
      {current && (
        <>
          <p className="text-sm text-gray-600">{current.title}</p>
          <StatsChip label={current.title_level.replace("_", " ")} />
        </>
      )}
      <div className="mt-auto pt-2">
        <SourceLink url={person.source_url} label={person.source_type} />
        <p className="text-xs text-gray-400 mt-1">
          Confidence: {Math.round(person.confidence * 100)}%
        </p>
      </div>
    </div>
  );
}
EOF

cat > apps/web/components/stats-chip.tsx << 'EOF'
interface Props {
  label: string;
}

export default function StatsChip({ label }: Props) {
  return (
    <span className="inline-block bg-blue-50 text-blue-700 text-xs font-medium px-2 py-0.5 rounded-full capitalize">
      {label}
    </span>
  );
}
EOF

cat > apps/web/components/source-link.tsx << 'EOF'
interface Props {
  url: string;
  label: string;
}

export default function SourceLink({ url, label }: Props) {
  return (
    <a
      href={url}
      target="_blank"
      rel="noopener noreferrer"
      className="text-xs text-blue-500 hover:underline truncate block"
    >
      Source: {label}
    </a>
  );
}
EOF

cat > apps/web/components/loading-state.tsx << 'EOF'
export default function LoadingState() {
  return (
    <div className="flex items-center justify-center py-20">
      <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
    </div>
  );
}
EOF

cat > apps/web/components/empty-state.tsx << 'EOF'
export default function EmptyState() {
  return (
    <div className="text-center py-20 text-gray-400">
      <p className="text-lg font-medium">No results found.</p>
      <p className="text-sm mt-1">Try a different university or adjust your filters.</p>
    </div>
  );
}
EOF

cat > apps/web/lib/api-client.ts << 'EOF'
const BASE = process.env.NEXT_PUBLIC_API_URL ?? "";

export async function fetchSearch(params: Record<string, string>) {
  const qs = new URLSearchParams(params).toString();
  const res = await fetch(`${BASE}/api/search?${qs}`);
  if (!res.ok) throw new Error("Search failed");
  return res.json();
}

export async function fetchUniversity(slug: string) {
  const res = await fetch(`${BASE}/api/universities/${slug}`);
  if (!res.ok) throw new Error("University not found");
  return res.json();
}
EOF

cat > apps/web/lib/formatters.ts << 'EOF'
export function formatTitleLevel(level: string): string {
  return level.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

export function formatConfidence(score: number): string {
  return `${Math.round(score * 100)}%`;
}
EOF

cat > apps/web/lib/query-state.ts << 'EOF'
export function parseSearchParams(
  params: Record<string, string | string[] | undefined>
): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(params)) {
    if (typeof v === "string") out[k] = v;
    else if (Array.isArray(v)) out[k] = v[0] ?? "";
  }
  return out;
}
EOF

cat > apps/web/styles/globals.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;
EOF

cat > apps/web/tailwind.config.ts << 'EOF'
import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: { extend: {} },
  plugins: [],
};

export default config;
EOF

cat > apps/web/tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "paths": { "@alumnimap/shared": ["../../packages/shared/src/index.ts"] }
  },
  "include": ["**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}
EOF

# ── apps/api ───────────────────────────────────────────────────────────────────

mkdir -p apps/api/src/{routes,services,adapters,validators,utils,types}
mkdir -p apps/api/tests

cat > apps/api/package.json << 'EOF'
{
  "name": "@alumnimap/api",
  "version": "0.0.1",
  "scripts": {
    "dev": "ts-node-dev --respawn src/index.ts",
    "build": "tsc",
    "test": "vitest run"
  },
  "dependencies": {
    "@supabase/supabase-js": "^2",
    "zod": "^3",
    "@alumnimap/shared": "*"
  },
  "devDependencies": {
    "typescript": "^5",
    "@types/node": "^20",
    "ts-node-dev": "^2",
    "vitest": "^1"
  }
}
EOF

cat > apps/api/src/types/api.ts << 'EOF'
import type { SearchResult, Institution } from "@alumnimap/shared";

export interface SearchResponse {
  results: SearchResult[];
  total: number;
  page: number;
  limit: number;
}

export interface UniversityResponse {
  institution: Institution;
  alumni_count: number;
  top_employers: { company: string; count: number }[];
}

export interface ErrorResponse {
  error: string;
  details?: unknown;
}
EOF

# Routes
cat > apps/api/src/routes/health.ts << 'EOF'
export async function healthHandler(): Promise<{ status: string }> {
  return { status: "ok" };
}
EOF

cat > apps/api/src/routes/search.ts << 'EOF'
import { SearchInputSchema } from "@alumnimap/shared";
import { runAlumniSearch } from "../services/alumni-search";
import type { SearchResponse, ErrorResponse } from "../types/api";

export async function searchHandler(
  query: Record<string, string>
): Promise<SearchResponse | ErrorResponse> {
  const parsed = SearchInputSchema.safeParse(query);
  if (!parsed.success) {
    return { error: "Invalid input", details: parsed.error.flatten() };
  }
  const results = await runAlumniSearch(parsed.data);
  return { results, total: results.length, page: parsed.data.page, limit: parsed.data.limit };
}
EOF

cat > apps/api/src/routes/universities.ts << 'EOF'
import { UniversityInputSchema } from "@alumnimap/shared";
import { resolveUniversity } from "../services/university-resolver";
import type { UniversityResponse, ErrorResponse } from "../types/api";

export async function universityHandler(
  slug: string
): Promise<UniversityResponse | ErrorResponse> {
  const institution = await resolveUniversity(slug);
  if (!institution) return { error: "University not found" };
  return { institution, alumni_count: 0, top_employers: [] };
}
EOF

cat > apps/api/src/routes/alumni.ts << 'EOF'
import { getSupabaseClient } from "../adapters/supabase-client";

export async function alumniHandler(personId: string) {
  const sb = getSupabaseClient();
  const { data, error } = await sb
    .from("people")
    .select("*, employment_history(*), education_history(*)")
    .eq("id", personId)
    .single();
  if (error) return { error: error.message };
  return { person: data };
}
EOF

cat > apps/api/src/routes/companies.ts << 'EOF'
import { getSupabaseClient } from "../adapters/supabase-client";

export async function companiesHandler(sector?: string) {
  const sb = getSupabaseClient();
  let q = sb.from("companies").select("*");
  if (sector) q = q.eq("sector", sector);
  const { data, error } = await q.limit(50);
  if (error) return { error: error.message };
  return { companies: data };
}
EOF

# Services
cat > apps/api/src/services/university-resolver.ts << 'EOF'
import { normalize, slugify } from "@alumnimap/shared";
import { getSupabaseClient } from "../adapters/supabase-client";
import type { Institution } from "@alumnimap/shared";

/** Resolve a raw university name or slug to a canonical Institution record. */
export async function resolveUniversity(
  input: string
): Promise<Institution | null> {
  const sb = getSupabaseClient();
  const normalized = normalize(input);
  const slug = slugify(input);

  const { data } = await sb
    .from("institutions")
    .select("*")
    .or(`slug.eq.${slug},name.ilike.%${normalized}%`)
    .limit(1)
    .single();

  return data ?? null;
}
EOF

cat > apps/api/src/services/alumni-search.ts << 'EOF'
import type { SearchInput, SearchResult } from "@alumnimap/shared";
import { resolveUniversity } from "./university-resolver";
import { fetchWikidataPeople } from "../adapters/wikidata-client";
import { scoreConfidence } from "./confidence-scorer";
import { dedupe } from "./deduper";
import { classifyTitle } from "./title-classifier";
import { mapSector } from "./sector-mapper";

/**
 * Orchestrates the full alumni search pipeline.
 * Steps: resolve → fetch → score → dedupe → classify → return.
 */
export async function runAlumniSearch(
  input: SearchInput
): Promise<SearchResult[]> {
  // 1. Resolve university
  const institution = await resolveUniversity(input.university);
  if (!institution) return [];

  // 2. Pull candidates from public sources
  const candidates = await fetchWikidataPeople(institution.name);

  // 3. Score confidence
  const scored = candidates.map(scoreConfidence);

  // 4. Deduplicate
  const deduped = dedupe(scored);

  // 5. Classify and filter
  const results: SearchResult[] = deduped
    .map((r) => ({
      ...r,
      employment: r.employment.map((e) => ({
        ...e,
        title_level: classifyTitle(e.title),
        sector: mapSector(r.company?.name ?? ""),
      })),
    }))
    .filter((r) => {
      if (input.title_level && !r.employment.some((e) => e.title_level === input.title_level)) return false;
      if (input.sector && !r.employment.some((e) => e.sector === input.sector)) return false;
      return true;
    });

  return results.slice((input.page - 1) * input.limit, input.page * input.limit);
}
EOF

cat > apps/api/src/services/confidence-scorer.ts << 'EOF'
import type { SearchResult } from "@alumnimap/shared";
import { clamp } from "@alumnimap/shared";

/** Assign a confidence score 0–1 based on source quality and field completeness. */
export function scoreConfidence(result: SearchResult): SearchResult {
  let score = 0.5;
  if (result.person.source_type === "wikidata") score += 0.2;
  if (result.person.source_type === "sec_filing") score += 0.3;
  if (result.employment.length > 0) score += 0.1;
  if (result.education.length > 0) score += 0.1;
  return {
    ...result,
    person: { ...result.person, confidence: clamp(score, 0, 1) },
  };
}
EOF

cat > apps/api/src/services/deduper.ts << 'EOF'
import type { SearchResult } from "@alumnimap/shared";
import { normalize } from "@alumnimap/shared";

/** Merge duplicate people records by normalized full name. */
export function dedupe(results: SearchResult[]): SearchResult[] {
  const seen = new Map<string, SearchResult>();
  for (const r of results) {
    const key = normalize(r.person.full_name);
    const existing = seen.get(key);
    if (!existing || r.person.confidence > existing.person.confidence) {
      seen.set(key, r);
    }
  }
  return Array.from(seen.values());
}
EOF

cat > apps/api/src/services/title-classifier.ts << 'EOF'
import type { TitleLevel } from "@alumnimap/shared";

const PATTERNS: [RegExp, TitleLevel][] = [
  [/\b(ceo|cto|coo|cfo|cpo|chief)\b/i, "c_suite"],
  [/\bfounder|co-founder\b/i, "founder"],
  [/\bvp|vice president\b/i, "vp"],
  [/\bdirector\b/i, "director"],
  [/\bmanager\b/i, "manager"],
];

/** Map a raw job title string to a TitleLevel. */
export function classifyTitle(title: string): TitleLevel {
  for (const [pattern, level] of PATTERNS) {
    if (pattern.test(title)) return level;
  }
  return "individual";
}
EOF

cat > apps/api/src/services/sector-mapper.ts << 'EOF'
const SECTOR_KEYWORDS: Record<string, string[]> = {
  technology: ["software", "tech", "ai", "data", "cloud", "cyber"],
  finance: ["bank", "capital", "invest", "financial", "fund", "asset"],
  healthcare: ["health", "medical", "pharma", "biotech", "hospital", "clinic"],
  government: ["department", "agency", "ministry", "federal", "state", "city"],
  education: ["university", "college", "school", "institute", "academy"],
  media: ["media", "news", "publishing", "broadcast", "journal"],
  consulting: ["consulting", "advisory", "partners", "strategy"],
  legal: ["law", "legal", "attorney", "counsel"],
  nonprofit: ["foundation", "nonprofit", "ngo", "charity"],
};

/** Map a company name to a sector string. */
export function mapSector(companyName: string): string {
  const lower = companyName.toLowerCase();
  for (const [sector, keywords] of Object.entries(SECTOR_KEYWORDS)) {
    if (keywords.some((kw) => lower.includes(kw))) return sector;
  }
  return "other";
}
EOF

cat > apps/api/src/services/source-priority.ts << 'EOF'
const PRIORITY: Record<string, number> = {
  sec_filing: 5,
  wikidata: 4,
  company_site: 3,
  university_page: 2,
  public_profile: 1,
};

/** Return whichever source type ranks higher. */
export function higherPriority(a: string, b: string): string {
  return (PRIORITY[a] ?? 0) >= (PRIORITY[b] ?? 0) ? a : b;
}
EOF

cat > apps/api/src/services/company-enricher.ts << 'EOF'
import { getSupabaseClient } from "../adapters/supabase-client";
import type { Company } from "@alumnimap/shared";

/** Look up or create a company record by name. */
export async function enrichCompany(name: string): Promise<Company | null> {
  const sb = getSupabaseClient();
  const { data } = await sb
    .from("companies")
    .select("*")
    .ilike("name", name)
    .limit(1)
    .single();
  return data ?? null;
}
EOF

# Adapters
cat > apps/api/src/adapters/supabase-client.ts << 'EOF'
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

let client: SupabaseClient | null = null;

export function getSupabaseClient(): SupabaseClient {
  if (!client) {
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!url || !key) throw new Error("Supabase env vars not set");
    client = createClient(url, key);
  }
  return client;
}
EOF

cat > apps/api/src/adapters/wikidata-client.ts << 'EOF'
import type { SearchResult } from "@alumnimap/shared";

const WIKIDATA_SPARQL = "https://query.wikidata.org/sparql";

/**
 * Query Wikidata for public figures associated with a university.
 * Returns a partial SearchResult array for further pipeline processing.
 */
export async function fetchWikidataPeople(
  universityName: string
): Promise<SearchResult[]> {
  const query = `
    SELECT ?person ?personLabel ?employerLabel ?title WHERE {
      ?university wdt:P31 wd:Q3918;
                  rdfs:label "${universityName}"@en.
      ?person wdt:P69 ?university;
              rdfs:label ?personLabel.
      OPTIONAL { ?person wdt:P108 ?employer. }
      OPTIONAL { ?person wdt:P39 ?titleNode. ?titleNode rdfs:label ?title. }
      FILTER(LANG(?personLabel) = "en")
    } LIMIT 50
  `;

  const url = `${WIKIDATA_SPARQL}?query=${encodeURIComponent(query)}&format=json`;

  const res = await fetch(url, {
    headers: { Accept: "application/sparql-results+json" },
  });

  if (!res.ok) return [];

  const json = await res.json();
  const bindings = json?.results?.bindings ?? [];

  return bindings.map((b: Record<string, { value: string }>) => ({
    person: {
      id: b.person?.value ?? crypto.randomUUID(),
      full_name: b.personLabel?.value ?? "Unknown",
      slug: "",
      source_url: b.person?.value ?? "",
      source_type: "wikidata",
      retrieved_at: new Date().toISOString(),
      confidence: 0.5,
      verified_fields: ["full_name"],
    },
    employment: b.employerLabel
      ? [
          {
            id: crypto.randomUUID(),
            person_id: b.person?.value ?? "",
            company_id: "",
            title: b.title?.value ?? "",
            title_level: "unknown" as const,
            sector: "",
            is_current: false,
          },
        ]
      : [],
    education: [],
    company: b.employerLabel
      ? {
          id: crypto.randomUUID(),
          name: b.employerLabel.value,
          slug: "",
        }
      : undefined,
  }));
}
EOF

cat > apps/api/src/adapters/public-web-fetcher.ts << 'EOF'
/**
 * Fetch a public URL and return raw text.
 * Only call URLs that are publicly accessible and not login-gated.
 */
export async function fetchPublicPage(url: string): Promise<string | null> {
  try {
    const res = await fetch(url, {
      headers: { "User-Agent": "AlumniMap/1.0 (public data indexer)" },
      signal: AbortSignal.timeout(8000),
    });
    if (!res.ok) return null;
    return await res.text();
  } catch {
    return null;
  }
}
EOF

cat > apps/api/src/adapters/company-site-parser.ts << 'EOF'
import { fetchPublicPage } from "./public-web-fetcher";

/** Extract leadership names from a public company about/team page. */
export async function parseLeadershipPage(
  url: string
): Promise<{ name: string; title: string }[]> {
  const html = await fetchPublicPage(url);
  if (!html) return [];
  // TODO: implement DOM parsing for structured leadership sections
  // Use a lightweight HTML parser (e.g. node-html-parser) here.
  return [];
}
EOF

# Validators
cat > apps/api/src/validators/search-input.ts << 'EOF'
export { SearchInputSchema } from "@alumnimap/shared";
EOF

cat > apps/api/src/validators/university-input.ts << 'EOF'
export { UniversityInputSchema } from "@alumnimap/shared";
EOF

# Utils
cat > apps/api/src/utils/normalize.ts << 'EOF'
export { normalize, slugify } from "@alumnimap/shared";
EOF

cat > apps/api/src/utils/logger.ts << 'EOF'
type Level = "info" | "warn" | "error";

export function log(level: Level, message: string, meta?: unknown): void {
  const entry = { level, message, ts: new Date().toISOString(), ...(meta ? { meta } : {}) };
  if (level === "error") console.error(JSON.stringify(entry));
  else console.log(JSON.stringify(entry));
}
EOF

cat > apps/api/src/utils/rate-limit.ts << 'EOF'
const counts = new Map<string, { n: number; reset: number }>();

/** Simple in-process rate limiter. Returns true if the key is within limit. */
export function checkRateLimit(key: string, limitPerMinute = 30): boolean {
  const now = Date.now();
  const entry = counts.get(key);
  if (!entry || now > entry.reset) {
    counts.set(key, { n: 1, reset: now + 60_000 });
    return true;
  }
  if (entry.n >= limitPerMinute) return false;
  entry.n++;
  return true;
}
EOF

cat > apps/api/src/utils/cache.ts << 'EOF'
import { CACHE_TTL_SECONDS } from "@alumnimap/shared";

const store = new Map<string, { value: unknown; expires: number }>();

export function cacheGet<T>(key: string): T | null {
  const entry = store.get(key);
  if (!entry || Date.now() > entry.expires) return null;
  return entry.value as T;
}

export function cacheSet(key: string, value: unknown, ttl = CACHE_TTL_SECONDS): void {
  store.set(key, { value, expires: Date.now() + ttl * 1000 });
}
EOF

# Tests
cat > apps/api/tests/university-resolver.test.ts << 'EOF'
import { describe, it, expect, vi } from "vitest";
import { resolveUniversity } from "../src/services/university-resolver";

vi.mock("../src/adapters/supabase-client", () => ({
  getSupabaseClient: () => ({
    from: () => ({
      select: () => ({
        or: () => ({
          limit: () => ({
            single: async () => ({
              data: {
                id: "1",
                name: "University of North Carolina",
                slug: "university-of-north-carolina",
                aliases: ["UNC"],
                country: "US",
                created_at: new Date().toISOString(),
              },
            }),
          }),
        }),
      }),
    }),
  }),
}));

describe("resolveUniversity", () => {
  it("returns a canonical institution for a valid name", async () => {
    const result = await resolveUniversity("UNC Chapel Hill");
    expect(result).not.toBeNull();
    expect(result?.name).toBe("University of North Carolina");
  });
});
EOF

cat > apps/api/tests/title-classifier.test.ts << 'EOF'
import { describe, it, expect } from "vitest";
import { classifyTitle } from "../src/services/title-classifier";

describe("classifyTitle", () => {
  it("classifies CEO as c_suite", () => expect(classifyTitle("CEO")).toBe("c_suite"));
  it("classifies Founder as founder", () => expect(classifyTitle("Co-Founder")).toBe("founder"));
  it("classifies VP Engineering as vp", () => expect(classifyTitle("VP Engineering")).toBe("vp"));
  it("classifies Director as director", () => expect(classifyTitle("Director of Sales")).toBe("director"));
  it("classifies unknown title as individual", () => expect(classifyTitle("Analyst")).toBe("individual"));
});
EOF

cat > apps/api/tests/deduper.test.ts << 'EOF'
import { describe, it, expect } from "vitest";
import { dedupe } from "../src/services/deduper";
import type { SearchResult } from "@alumnimap/shared";

const make = (name: string, confidence: number): SearchResult => ({
  person: {
    id: crypto.randomUUID(),
    full_name: name,
    slug: "",
    source_url: "https://example.com",
    source_type: "wikidata",
    retrieved_at: new Date().toISOString(),
    confidence,
    verified_fields: [],
  },
  employment: [],
  education: [],
});

describe("dedupe", () => {
  it("keeps the higher-confidence record when names match", () => {
    const results = dedupe([make("Jane Smith", 0.4), make("Jane Smith", 0.9)]);
    expect(results).toHaveLength(1);
    expect(results[0].person.confidence).toBe(0.9);
  });

  it("keeps distinct people", () => {
    const results = dedupe([make("Jane Smith", 0.8), make("John Doe", 0.7)]);
    expect(results).toHaveLength(2);
  });
});
EOF

cat > apps/api/tests/confidence-scorer.test.ts << 'EOF'
import { describe, it, expect } from "vitest";
import { scoreConfidence } from "../src/services/confidence-scorer";
import type { SearchResult } from "@alumnimap/shared";

const base: SearchResult = {
  person: {
    id: "1",
    full_name: "Test Person",
    slug: "",
    source_url: "https://wikidata.org/wiki/Q1",
    source_type: "wikidata",
    retrieved_at: new Date().toISOString(),
    confidence: 0,
    verified_fields: [],
  },
  employment: [],
  education: [],
};

describe("scoreConfidence", () => {
  it("boosts score for wikidata source", () => {
    const result = scoreConfidence(base);
    expect(result.person.confidence).toBeGreaterThan(0.5);
  });

  it("clamps score to 1", () => {
    const result = scoreConfidence({
      ...base,
      person: { ...base.person, source_type: "sec_filing" },
      employment: [{ id: "1", person_id: "1", company_id: "1", title: "CEO", title_level: "c_suite", sector: "finance", is_current: true }],
      education: [{ id: "1", person_id: "1", institution_id: "1" }],
    });
    expect(result.person.confidence).toBeLessThanOrEqual(1);
  });
});
EOF

# Supabase migrations
mkdir -p supabase/migrations

cat > supabase/migrations/001_init.sql << 'EOF'
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
EOF

# Docs
mkdir -p docs

cat > docs/architecture.md << 'EOF'
# Architecture

Monorepo with three packages:
- `apps/web` — Next.js 14 frontend
- `apps/api` — serverless route handlers and pipeline services
- `packages/shared` — shared types, schemas, constants, utils

## Request flow
1. User submits university search.
2. `apps/web` calls `/api/search` via `api-client.ts`.
3. `search.ts` validates input with Zod.
4. `alumni-search.ts` runs the five-step pipeline.
5. Results returned with source URLs and confidence scores.
EOF

cat > docs/data-sources.md << 'EOF'
# Data Sources

All sources must be publicly accessible without authentication.

| Source | Adapter | Notes |
|---|---|---|
| Wikidata SPARQL | `wikidata-client.ts` | Primary source for public figures |
| Company public pages | `company-site-parser.ts` | Leadership/about pages only |
| SEC filings | `public-web-fetcher.ts` | Executive officer sections |
| University pages | `public-web-fetcher.ts` | Alumni spotlights, faculty |

Never scrape LinkedIn, Crunchbase paid tiers, or any login-gated page.
EOF

cat > docs/privacy.md << 'EOF'
# Privacy and Compliance

- Only store publicly accessible information.
- Every record must include `source_url`.
- No bypassing paywalls or login gates.
- No scraping restricted platforms.
- Cache aggressively to minimize repeated fetches.
- Users can request removal of their data via the contact page.
EOF

cat > docs/roadmap.md << 'EOF'
# Roadmap

## Phase 1 — Search by university
- University resolver
- Wikidata adapter
- Basic results grid

## Phase 2 — Filters
- Title level filter
- Sector filter
- Company type filter

## Phase 3 — Company clustering
- Top employer stats
- Leader highlights per employer

## Phase 4 — Saved searches
- Auth via Supabase
- Saved search history
- Shareable report URLs
EOF

cat > README.md << 'EOF'
# AlumniMap

University alumni intelligence platform. Enter a university, discover where alumni work and lead.

## Stack
- **Frontend**: Next.js 14 + Tailwind CSS
- **Backend**: Vercel serverless functions
- **Database**: Supabase (Postgres + Auth)
- **Validation**: Zod
- **Testing**: Vitest

## Local development

```bash
cp .env.local .env.local   # fill in Supabase credentials
npm install
npx supabase db push       # run migrations
npm run dev:web            # http://localhost:3000
npm run dev:api            # http://localhost:3001
```

## Testing

```bash
npm run test
```

## Deployment
- Frontend + API: Vercel Hobby
- Database: Supabase Free
EOF

echo ""
echo "✅ AlumniMap scaffolded successfully."
echo ""
echo "Next steps:"
echo "  1. cd alumnimap"
echo "  2. Fill in .env.local with your Supabase credentials"
echo "  3. npm install"
echo "  4. Run Supabase migrations: npx supabase db push"
echo "  5. npm run dev:web"