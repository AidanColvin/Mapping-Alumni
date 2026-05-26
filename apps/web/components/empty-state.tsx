export default function EmptyState() {
  return (
    <div className="text-center py-20 text-gray-400">
      <p className="text-lg font-medium">No results found.</p>
      <p className="text-sm mt-2">
        Try a different university name, or adjust your filters.
      </p>
      <p className="text-xs mt-4 text-gray-300">
        Only public Wikidata records are searched.
      </p>
    </div>
  );
}
