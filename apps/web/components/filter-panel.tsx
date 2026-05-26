"use client";
import { useRouter, useSearchParams } from "next/navigation";
import { SECTORS, TITLE_LEVELS } from "@alumnimap/shared";

interface Props {
  filters: Record<string, string>;
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
    <div className="flex flex-wrap gap-3 mb-6 p-4 bg-white border border-gray-200 rounded-xl">
      <select
        value={filters.sector ?? ""}
        onChange={(e) => update("sector", e.target.value)}
        className="border rounded px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
        aria-label="Filter by sector"
      >
        <option value="">All sectors</option>
        {SECTORS.map((s) => (
          <option key={s} value={s}>
            {s.charAt(0).toUpperCase() + s.slice(1)}
          </option>
        ))}
      </select>

      <select
        value={filters.title_level ?? ""}
        onChange={(e) => update("title_level", e.target.value)}
        className="border rounded px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400"
        aria-label="Filter by title level"
      >
        <option value="">All levels</option>
        {TITLE_LEVELS.map((t) => (
          <option key={t} value={t}>
            {t.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase())}
          </option>
        ))}
      </select>

      <input
        type="text"
        value={filters.keyword ?? ""}
        onChange={(e) => update("keyword", e.target.value)}
        placeholder="Keyword search..."
        className="border rounded px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-400 min-w-[160px]"
        aria-label="Keyword filter"
      />

      {(filters.sector || filters.title_level || filters.keyword) && (
        <button
          onClick={() => {
            const next = new URLSearchParams(params.toString());
            next.delete("sector");
            next.delete("title_level");
            next.delete("keyword");
            router.push(`/search?${next.toString()}`);
          }}
          className="text-xs text-gray-400 hover:text-red-500 px-2 py-1 rounded border border-gray-200"
        >
          Clear filters
        </button>
      )}
    </div>
  );
}
