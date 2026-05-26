// Single responsibility API client for the Next.js frontend
const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://127.0.0.1:8000/api";

export async function fetchSearch(params: Record<string, string>) {
    const query = new URLSearchParams(params).toString();
    const res = await fetch(`${API_URL}/search?${query}`);
    if (!res.ok) throw new Error("Failed to fetch search results");
    return res.json();
}

export async function fetchUniversity(slug: string) {
    const res = await fetch(`${API_URL}/universities/${slug}`);
    if (!res.ok) throw new Error("Failed to fetch university data");
    return res.json();
}

export async function fetchStats() {
    const res = await fetch(`${API_URL}/stats`);
    if (!res.ok) throw new Error("Failed to fetch stats");
    return res.json();
}
