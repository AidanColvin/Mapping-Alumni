const UNC_DEMO_DATA = {
    results: [
        {
            person: { full_name: "Chuck Robbins", source_type: "Wikipedia", source_url: "https://en.wikipedia.org/wiki/Chuck_Robbins" },
            employment: { title: "CEO", company: { name: "Cisco Systems", sector: "Technology" } },
            confidence: 0.99,
            sector: "Technology",
            title_level: "C-Suite"
        },
        {
            person: { full_name: "Michele Buck", source_type: "Wikipedia", source_url: "https://en.wikipedia.org/wiki/Michele_Buck" },
            employment: { title: "CEO", company: { name: "The Hershey Company", sector: "Consumer Goods" } },
            confidence: 0.99,
            sector: "Consumer Goods",
            title_level: "C-Suite"
        },
        {
            person: { full_name: "Bill Rogers", source_type: "Company Site", source_url: "https://www.truist.com" },
            employment: { title: "CEO", company: { name: "Truist Financial", sector: "Finance" } },
            confidence: 0.98,
            sector: "Finance",
            title_level: "C-Suite"
        }
    ],
    total: 3,
    institution: { name: "University of North Carolina at Chapel Hill", slug: "unc-chapel-hill", wikidata_id: "Q192882" }
};

export async function fetchSearch(params: Record<string, string>) {
    // Force return of demo data for any search
    return UNC_DEMO_DATA;
}

export async function fetchUniversity(slug: string) {
    return { 
        institution: UNC_DEMO_DATA.institution, 
        top_employers: [
            { employer: "Cisco Systems", count: 1 }, 
            { employer: "The Hershey Company", count: 1 },
            { employer: "Truist Financial", count: 1 }
        ] 
    };
}

export async function fetchStats() {
    return { institutions: 1, people: 3, employment_records: 3 };
}
