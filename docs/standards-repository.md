# ONYX-20 Standards Repository

This package populates the Windfix AI standards knowledge base from the Obsidian vault sources used in `ONYX-20`.

Files:

- `supabase/seed/onyx20_standards_seed.json`
- `scripts/seed-onyx20-standards.mjs`

Coverage:

- 7 standards entries in `standards_repository`
- 30 damage taxonomy codes represented in `damage_repair_mapping`
- 45 mapping rows after expanding multi-standard citations
- GWO scope gate encoded in the knowledge pack and carried into mapping scope strings
- Complexity tiers `T1` to `T5` defined in `ai-service/knowledge/standards/standards-pack.json`

Seed usage:

```powershell
$env:SUPABASE_URL='https://<project-ref>.supabase.co'
$env:SUPABASE_SERVICE_ROLE_KEY='<service-role-key>'
node scripts/seed-onyx20-standards.mjs
```
