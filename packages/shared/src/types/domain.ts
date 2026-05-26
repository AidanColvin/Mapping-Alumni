// TypeScript representations of the Python Pydantic models
export interface Company {
    name: string;
    domain?: string;
    sector?: string;
}

export interface Employment {
    title: string;
    company: Company;
}

export interface Person {
    full_name: string;
    wikidata_id?: string;
    source_type?: string;
    source_url?: string;
}

export interface SearchResult {
    person: Person;
    employment?: Employment;
    confidence: number;
    sector?: string;
    title_level?: string;
}

export interface Institution {
    name: string;
    slug: string;
    wikidata_id?: string;
}
