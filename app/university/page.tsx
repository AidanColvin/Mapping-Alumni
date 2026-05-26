"use client";

import { Suspense, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import type { UniversityResponse } from "@alumnimap/shared";
import LoadingState from "../../components/loading-state";
import { fetchUniversity } from "../../lib/api-client";
import { formatTitleLevel } from "../../lib/formatters";

function UniversityInner() {
  const params = useSearchParams();
  const slug = params.get("slug");
  const [data, setData] = useState<UniversityResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!slug) {
      setError("Missing slug parameter.");
      setLoading(false);
      return;
    }
    setLoading(true);
    fetchUniversity(slug)
      .then(setData)
      .catch((e: Error) => setError(e.message))
      .finally(() => setLoading(false));
  }, [slug]);

  if (loading) return <LoadingState />;
  if (error) return <p className="p-8 text-red-500">{error}</p>;
  if (!data) return <p className="p-8">No data.</p>;

  return (
    <div className="max-w-5xl mx-auto px-4 py-10">
      <h1 className="text-3xl font-bold mb-1">{data.institution.name}</h1>
      {data.institution.country && (
        <p className="text-gray-400 text-sm mb-6">{data.institution.country}</p>
      )}
      <p className="text-gray-500 mb-8 text-lg">
        {data.alumni_count} alumni indexed
      </p>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8 mb-10">
        <div>
          <h2 className="text-xl font-semibold mb-3">Top Employers</h2>
          <ul className="space-y-2">
            {data.top_employers.map((e) => (
              <li key={e.company} className="flex justify-between border-b py-2 text-sm">
                <span>{e.company}</span>
                <span className="text-gray-400">{e.count}</span>
              </li>
            ))}
          </ul>
        </div>

        <div>
          <h2 className="text-xl font-semibold mb-3">By Role Level</h2>
          <ul className="space-y-2">
            {Object.entries(data.title_level_breakdown).map(([lvl, cnt]) => (
              <li key={lvl} className="flex justify-between border-b py-2 text-sm">
                <span>{formatTitleLevel(lvl)}</span>
                <span className="text-gray-400">{cnt}</span>
              </li>
            ))}
          </ul>
        </div>
      </div>

      <div>
        <h2 className="text-xl font-semibold mb-3">By Sector</h2>
        <div className="flex flex-wrap gap-2">
          {Object.entries(data.sector_breakdown).map(([sector, cnt]) => (
            <span key={sector} className="bg-blue-50 text-blue-700 text-xs px-3 py-1 rounded-full">
              {sector} ({cnt})
            </span>
          ))}
        </div>
      </div>
    </div>
  );
}

export default function UniversityPage() {
  return (
    <Suspense fallback={<LoadingState />}>
      <UniversityInner />
    </Suspense>
  );
}
