"use client";

import { Suspense, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import type { SearchResponse } from "@alumnimap/shared";
import FilterPanel from "../../components/filter-panel";
import ResultsGrid from "../../components/results-grid";
import LoadingState from "../../components/loading-state";
import EmptyState from "../../components/empty-state";
import { fetchSearch } from "../../lib/api-client";

function SearchInner() {
  const params = useSearchParams();
  const [data, setData] = useState<SearchResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const filters = Object.fromEntries(params.entries());
  const paramsKey = params.toString();

  useEffect(() => {
    if (!filters.university) {
      setError("No university specified.");
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    fetchSearch(filters as any)
      .then(setData)
      .catch((e: Error) => setError(e.message))
      .finally(() => setLoading(false));
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [paramsKey]);

  if (loading) return <LoadingState />;
  if (error) return <p className="p-8 text-red-500">{error}</p>;
  if (!data || !data.results.length) return <EmptyState />;

  return (
    <div className="max-w-5xl mx-auto px-4 py-10">
      {data.institution && (
        <div className="mb-6">
          <h1 className="text-2xl font-bold">{data.institution.name}</h1>
          <p className="text-gray-500 text-sm mt-1">
            {data.total} alumni found
            {data.institution.country ? ` · ${data.institution.country}` : ""}
          </p>
        </div>
      )}
      <FilterPanel filters={filters} />
      <ResultsGrid results={data.results} />
      {data.total > data.results.length && (
        <p className="text-center text-sm text-gray-400 mt-6">
          Showing {data.results.length} of {data.total} results
        </p>
      )}
    </div>
  );
}

export default function SearchPage() {
  return (
    <Suspense fallback={<LoadingState />}>
      <SearchInner />
    </Suspense>
  );
}
