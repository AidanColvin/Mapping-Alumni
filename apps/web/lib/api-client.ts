import type { SearchFilters, SearchResponse, UniversityResponse } from "@alumnimap/shared";

const BASE = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000";

function buildQs(params: Record<string, string | number | undefined>): string {
  const qs = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== "") qs.set(k, String(v));
  }
  return qs.toString();
}

export async function fetchSearch(filters: SearchFilters): Promise<SearchResponse> {
  const qs = buildQs(filters as Record<string, string | number | undefined>);
  const res = await fetch(`${BASE}/api/search?${qs}`);
  if (res.status === 404) return { results: [], total: 0, page: 1, limit: 20, institution: null };
  if (!res.ok) throw new Error(`Search failed: ${res.status}`);
  return res.json();
}

export async function fetchUniversity(slug: string): Promise<UniversityResponse> {
  const res = await fetch(`${BASE}/api/universities/${slug}`);
  if (!res.ok) throw new Error(`University not found: ${res.status}`);
  return res.json();
}

export async function fetchSources(): Promise<{ allowed_domains: string[] }> {
  const res = await fetch(`${BASE}/api/sources`);
  if (!res.ok) throw new Error("Failed to fetch sources");
  return res.json();
}

export async function fetchStats() {
  const res = await fetch(`${BASE}/api/stats`);
  if (!res.ok) throw new Error("Failed to fetch stats");
  return res.json();
}
