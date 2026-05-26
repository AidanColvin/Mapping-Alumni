#!/bin/bash
set -e

echo "🚀 Configuring Next.js for GitHub Pages..."
echo ""

REPO_NAME="Mapping-Alumni"
GH_USER="AidanColvin"

# ── 1. next.config.js — enable static export ─────────────────────────────────
cat > apps/web/next.config.js << EOF
/** @type {import('next').NextConfig} */
const isProd = process.env.NODE_ENV === "production";

const nextConfig = {
  output: "export",
  basePath: isProd ? "/${REPO_NAME}" : "",
  assetPrefix: isProd ? "/${REPO_NAME}/" : "",
  images: { unoptimized: true },
  trailingSlash: true,
};

module.exports = nextConfig;
EOF

# Remove conflicting tsconfig from prior next dev run (it added .next/types/**/*.ts)
# Keep the existing tsconfig; Next will regenerate as needed.

# ── 2. Production env — points at hosted backend ─────────────────────────────
cat > apps/web/.env.production << 'EOF'
# Replace with your deployed FastAPI URL after deploying backend
NEXT_PUBLIC_API_URL=https://alumnimap-api.onrender.com
EOF

# ── 3. Convert search page to client component (static export safe) ───────────
cat > apps/web/app/search/page.tsx << 'EOF'
"use client";

import { Suspense, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import FilterPanel from "../../components/filter-panel";
import ResultsGrid from "../../components/results-grid";
import LoadingState from "../../components/loading-state";
import EmptyState from "../../components/empty-state";

function SearchInner() {
  const params = useSearchParams();
  const [results, setResults] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const filters = Object.fromEntries(params.entries());

  useEffect(() => {
    const apiUrl = process.env.NEXT_PUBLIC_API_URL;
    if (!apiUrl) {
      setError("Backend not configured. Set NEXT_PUBLIC_API_URL.");
      setLoading(false);
      return;
    }
    const qs = new URLSearchParams(filters).toString();
    fetch(`${apiUrl}/api/search?${qs}`)
      .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
      .then((data) => setResults(data.results ?? []))
      .catch((e) => setError(`Failed to load results (${e})`))
      .finally(() => setLoading(false));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [params.toString()]);

  if (loading) return <LoadingState />;
  if (error) return <p className="p-8 text-red-500">{error}</p>;
  if (!results.length) return <EmptyState />;

  return (
    <div className="max-w-5xl mx-auto px-4 py-10">
      <FilterPanel filters={filters} />
      <ResultsGrid results={results} />
    </div>
  );
}

export default function SearchPage() {
  return (
    <Suspense fallback={<LoadingState />}>
      <SearchInner />
    </Suspense>
  );
}
EOF

# ── 4. Replace dynamic university route with querystring version ─────────────
# Static export can't generate arbitrary [slug] paths — use ?slug=xxx instead.
rm -rf "apps/web/app/university/[slug]"
mkdir -p apps/web/app/university

cat > apps/web/app/university/page.tsx << 'EOF'
"use client";

import { Suspense, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import LoadingState from "../../components/loading-state";

function UniversityInner() {
  const params = useSearchParams();
  const slug = params.get("slug");
  const [data, setData] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!slug) {
      setError("Missing slug parameter.");
      setLoading(false);
      return;
    }
    const apiUrl = process.env.NEXT_PUBLIC_API_URL;
    if (!apiUrl) {
      setError("Backend not configured.");
      setLoading(false);
      return;
    }
    fetch(`${apiUrl}/api/universities/${slug}`)
      .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
      .then(setData)
      .catch((e) => setError(`Failed to load university (${e})`))
      .finally(() => setLoading(false));
  }, [slug]);

  if (loading) return <LoadingState />;
  if (error) return <p className="p-8 text-red-500">{error}</p>;
  if (!data) return <p className="p-8">No data.</p>;

  return (
    <div className="max-w-5xl mx-auto px-4 py-10">
      <h1 className="text-3xl font-bold mb-2">{data.institution?.name}</h1>
      <p className="text-gray-500 mb-8">
        {data.alumni_count} alumni indexed
      </p>
      <h2 className="text-xl font-semibold mb-3">Top employers</h2>
      <ul className="space-y-2">
        {(data.top_employers ?? []).map((e: any) => (
          <li key={e.company} className="flex justify-between border-b py-2">
            <span>{e.company}</span>
            <span className="text-gray-500">{e.count}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}

export default function UniversityPage() {
  return (
    <Suspense fallback={<LoadingState />}>
      <UniversityInner />
    </Suspense>
  );
}
EOF

# ── 5. GitHub Actions workflow ────────────────────────────────────────────────
mkdir -p .github/workflows

cat > .github/workflows/deploy-pages.yml << 'EOF'
name: Deploy frontend to GitHub Pages

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: true

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm

      - name: Install deps (workspace root)
        run: npm install

      - name: Build static site
        env:
          NEXT_PUBLIC_API_URL: ${{ vars.NEXT_PUBLIC_API_URL }}
        run: npm run build --workspace=apps/web

      - name: Add .nojekyll
        run: touch apps/web/out/.nojekyll

      - uses: actions/configure-pages@v5

      - uses: actions/upload-pages-artifact@v3
        with:
          path: apps/web/out

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
EOF

# ── 6. Add `build` script to apps/web/package.json if not present ────────────
# (Already added it earlier via scaffold — verify.)
node -e "
const fs = require('fs');
const p = JSON.parse(fs.readFileSync('apps/web/package.json'));
p.scripts = p.scripts || {};
p.scripts.build = 'next build';
fs.writeFileSync('apps/web/package.json', JSON.stringify(p, null, 2));
"

# ── 7. README addendum for GitHub Pages ──────────────────────────────────────
cat >> README.md << EOF

## GitHub Pages deployment

The frontend deploys automatically to GitHub Pages on every push to \`main\`.

**One-time setup:**

1. Push this repo to \`github.com/${GH_USER}/${REPO_NAME}\`.
2. In repo settings → **Pages** → set Source to **GitHub Actions**.
3. In repo settings → **Secrets and variables → Actions → Variables**, add:
   - \`NEXT_PUBLIC_API_URL\` = the public URL of your deployed FastAPI backend
4. Push to \`main\`. The site builds and deploys to \`https://${GH_USER,,}.github.io/${REPO_NAME}/\`.

**Backend deployment (Render free tier — easiest):**

1. Sign in to render.com with GitHub.
2. New → Web Service → connect this repo.
3. Settings:
   - Root Directory: \`apps/api\`
   - Build Command: \`pip install -r requirements.txt\`
   - Start Command: \`uvicorn app.main:app --host 0.0.0.0 --port \$PORT\`
4. Copy the deploy URL into the \`NEXT_PUBLIC_API_URL\` GitHub Actions variable.
EOF

# Some shells don't expand \${GH_USER,,} — make sure it's lowercased even if literal stayed
sed -i.bak "s|\${GH_USER,,}|aidancolvin|g" README.md && rm README.md.bak

echo ""
echo "✅ GitHub Pages configuration complete."
echo ""
echo "Next steps:"
echo "  1. git init && git add . && git commit -m 'Initial commit'"
echo "  2. Create the repo on GitHub: gh repo create ${REPO_NAME} --public --source=. --push"
echo "     (or create manually and: git remote add origin URL && git push -u origin main)"
echo "  3. In repo Settings → Pages, set source to 'GitHub Actions'"
echo "  4. In repo Settings → Variables, add NEXT_PUBLIC_API_URL"
echo "  5. Site will be live at: https://aidancolvin.github.io/${REPO_NAME}/"
