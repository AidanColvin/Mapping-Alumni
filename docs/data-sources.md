# Data Sources

All sources must be publicly accessible without authentication.

| Source | Adapter | Notes |
|---|---|---|
| Wikidata SPARQL | `wikidata-client.ts` | Primary source for public figures |
| Company public pages | `company-site-parser.ts` | Leadership/about pages only |
| SEC filings | `public-web-fetcher.ts` | Executive officer sections |
| University pages | `public-web-fetcher.ts` | Alumni spotlights, faculty |

Never scrape LinkedIn, Crunchbase paid tiers, or any login-gated page.
