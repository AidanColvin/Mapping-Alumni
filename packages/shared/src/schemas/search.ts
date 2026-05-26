import { z } from "zod";

export const SearchInputSchema = z.object({
  university: z.string().min(2).max(120),
  sector: z.string().optional(),
  title_level: z
    .enum(["c_suite", "founder", "vp", "director", "manager", "individual", "unknown"])
    .optional(),
  company_type: z.string().optional(),
  region: z.string().optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

export type SearchInput = z.infer<typeof SearchInputSchema>;

export const UniversityInputSchema = z.object({
  query: z.string().min(2).max(120),
});

export type UniversityInput = z.infer<typeof UniversityInputSchema>;
