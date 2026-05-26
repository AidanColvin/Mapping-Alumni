export function LoadingState() {
  return (
    <div
      role="status"
      aria-label="Loading results"
      className="flex justify-center items-center py-16"
    >
      <div className="animate-spin rounded-full h-10 w-10 border-4 border-blue-500 border-t-transparent" />
      <span className="sr-only">Loading…</span>
    </div>
  );
}
