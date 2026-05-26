export function parseSearchParams(
  params: Record<string, string | string[] | undefined>
): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(params)) {
    if (typeof v === "string") out[k] = v;
    else if (Array.isArray(v)) out[k] = v[0] ?? "";
  }
  return out;
}
