import type { SearchResult } from "@alumnimap/shared";
import SourceLink from "./source-link";
import StatsChip from "./stats-chip";

interface Props {
  result: SearchResult;
}

export default function AlumniCard({ result }: Props) {
  const { person, employment } = result;
  // Use the first current employment; fall back to first available
  const current = employment.find((e) => e.is_current) ?? employment[0] ?? null;

  return (
    <div className="border border-gray-200 rounded-xl p-4 bg-white shadow-sm flex flex-col gap-2 hover:shadow-md transition-shadow">
      <p className="font-semibold text-base leading-tight">{person.full_name}</p>

      {current && (
        <>
          {current.company && (
            <p className="text-sm text-gray-700 font-medium">{current.company.name}</p>
          )}
          {current.title && (
            <p className="text-xs text-gray-500 italic">{current.title}</p>
          )}
          <div className="flex flex-wrap gap-1">
            {current.title_level !== "unknown" && (
              <StatsChip label={current.title_level.replace(/_/g, " ")} variant="blue" />
            )}
            {current.sector && current.sector !== "other" && (
              <StatsChip label={current.sector} variant="gray" />
            )}
          </div>
        </>
      )}

      <div className="mt-auto pt-2 border-t border-gray-100">
        <SourceLink url={person.source_url} label={person.source_type} />
        <p className="text-xs text-gray-400 mt-1">
          Confidence: {Math.round(person.confidence * 100)}%
        </p>
      </div>
    </div>
  );
}
