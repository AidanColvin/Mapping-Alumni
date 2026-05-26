# Architecture

Monorepo with three packages:
- `apps/web` — Next.js 14 frontend
- `apps/api` — serverless route handlers and pipeline services
- `packages/shared` — shared types, schemas, constants, utils

## Request flow
1. User submits university search.
2. `apps/web` calls `/api/search` via `api-client.ts`.
3. `search.ts` validates input with Zod.
4. `alumni-search.ts` runs the five-step pipeline.
5. Results returned with source URLs and confidence scores.
