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
  "wikipedia",
  "company_site",
  "sec_filing",
  "university_page",
] as const;

export const CACHE_TTL_SECONDS = 60 * 60 * 6; // 6 hours
export const MAX_RESULTS_PER_PAGE = 50;

export const TITLE_LEVEL_LABELS: Record<string, string> = {
  c_suite: "C-Suite",
  founder: "Founder",
  vp: "VP",
  director: "Director",
  manager: "Manager",
  individual: "Individual Contributor",
  unknown: "Unknown",
};
