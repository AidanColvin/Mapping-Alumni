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
