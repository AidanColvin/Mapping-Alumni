const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://127.0.0.1:8000/api";

const UNC_DEMO_DATA = {
    results: [
        {
            person: { full_name: "Michele Buck", source_type: "Wikipedia", source_url: "https://en.wikipedia.org/wiki/Michele_Buck" },
            employment: { title: "CEO", company: { name: "The Hershey Company", sector: "Consumer Goods" } },
            confidence: 0.99,
            sector: "Consumer Goods",
            title_level: "C-Suite"
        },
        {
            person: { full_name: "Sallie Krawcheck", source_type: "Wikidata", source_url: "https://www.wikidata.org/wiki/Q7404987" },
            employment: { title: "CEO", company: { name: "Merrill Lynch", sector: "Finance" } },
            confidence: 0.98,
            sector: "Finance",
            title_level: "C-Suite"
        },
        {
            person: { full_name: "Robert Niblock", source_type: "SEC Filings", source_url: "https://www.sec.gov" },
            employment: { title: "CEO", company: { name: "Lowe's Companies", sector: "Retail" } },
            confidence: 0.99,
            sector: "Retail",
            title_level: "C-Suite"
        },
        {
            person: { full_name: "Hugh McColl Jr.", source_type: "Wikidata", source_url: "https://www.wikidata.org/wiki/Q5931752" },
            employment: { title: "CEO", company: { name: "Bank of America", sector: "Finance" } },
            confidence: 0.95,
            sector: "Finance",
            title_level: "C-Suite"
        },
        {
            person: { full_name: "Joseph Swedish", source_type: "Company Site", source_url: "https://www.elevancehealth.com" },
            employment: { title: "CEO", company: { name: "Anthem, Inc.", sector: "Healthcare" } },
            confidence: 0.96,
            sector: "Healthcare",
            title_level: "C-Suite"
        }
    ],
    total: 5,
    institution: { name: "University of North Carolina at Chapel Hill", slug: "unc-chapel-hill", wikidata_id: "Q192882" }
};

export async function fetchSearch(params: Record<string, string>) {
    try {
        const query = new URLSearchParams(params).toString();
        const res = await fetch(`${API_URL}/search?${query}`);
        if (!res.ok) throw new Error("Backend unavailable");
        return await res.json();
    } catch (error) {
        console.warn("API unreachable. Falling back to Fortune 500 Demo Mode.");
        const searchStr = (params.university || "").toLowerCase();
        if (searchStr.includes("unc") || searchStr.includes("chapel hill") || searchStr.includes("north carolina")) {
            return UNC_DEMO_DATA;
        }
        return { results: [], total: 0, institution: null };
    }
}

export async function fetchUniversity(slug: string) {
    try {
        const res = await fetch(`${API_URL}/universities/${slug}`);
        if (!res.ok) throw new Error("Backend unavailable");
        return await res.json();
    } catch (error) {
        if (slug.includes("unc") || slug.includes("chapel-hill")) {
            return { 
                institution: UNC_DEMO_DATA.institution, 
                top_employers: [
                    { employer: "Bank of America", count: 1 }, 
                    { employer: "Lowe's Companies", count: 1 },
                    { employer: "The Hershey Company", count: 1 }
                ] 
            };
        }
        throw error;
    }
}

export async function fetchStats() {
    try {
        const res = await fetch(`${API_URL}/stats`);
        if (!res.ok) throw new Error("Backend unavailable");
        return await res.json();
    } catch (error) {
        return { institutions: 1, people: 5, employment_records: 5 };
    }
}
