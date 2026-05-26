"use client";

interface FilterPanelProps {
  filters: Record<string, string>;
  onChange: (key: string, value: string) => void;
}

const SECTORS = [
  "", "technology", "finance", "healthcare", "consulting", "education",
  "government", "media", "legal", "nonprofit", "energy", "consumer",
  "real_estate", "telecom", "transportation", "defense", "other",
];

const TITLE_LEVELS = [
  "", "founder", "c_suite", "vp", "director", "manager",
  "government", "academic", "medical", "individual_contributor", "other",
];

export function FilterPanel({ filters, onChange }: FilterPanelProps) {
  return (
    <div className="flex flex-wrap gap-3 items-end">
      <label className="flex flex-col gap-1 text-sm font-medium">
        Sector
        <select
          value={filters.sector ?? ""}
          onChange={(e) => onChange("sector", e.target.value)}
          className="border rounded px-2 py-1 text-sm"
        >
          {SECTORS.map((s) => (
            <option key={s} value={s}>{s === "" ? "All sectors" : s}</option>
          ))}
        </select>
      </label>

      <label className="flex flex-col gap-1 text-sm font-medium">
        Title level
        <select
          value={filters.title_level ?? ""}
          onChange={(e) => onChange("title_level", e.target.value)}
          className="border rounded px-2 py-1 text-sm"
        >
          {TITLE_LEVELS.map((t) => (
            <option key={t} value={t}>{t === "" ? "All levels" : t}</option>
          ))}
        </select>
      </label>

      <label className="flex flex-col gap-1 text-sm font-medium">
        Keyword
        <input
          type="text"
          value={filters.keyword ?? ""}
          onChange={(e) => onChange("keyword", e.target.value)}
          placeholder="Name, company…"
          className="border rounded px-2 py-1 text-sm w-40"
        />
      </label>
    </div>
  );
}
