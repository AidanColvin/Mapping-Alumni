export function formatTitleLevel(level: string): string {
  return level.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

export function formatConfidence(score: number): string {
  return `${Math.round(score * 100)}%`;
}
