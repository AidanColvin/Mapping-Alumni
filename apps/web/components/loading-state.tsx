export default function LoadingState() {
  return (
    <div
      role="status"
      aria-label="Loading results"
      className="flex flex-col items-center justify-center py-20 gap-3"
    >
      <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
      <p className="text-sm text-gray-400">Loading alumni data…</p>
    </div>
  );
}
