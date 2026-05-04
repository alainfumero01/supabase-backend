import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const seedPath = path.resolve(__dirname, "..", "supabase", "seed", "onyx20_standards_seed.json");

const supabaseUrl = process.env.SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required.");
}

const headers = {
  apikey: serviceRoleKey,
  Authorization: `Bearer ${serviceRoleKey}`,
  "Content-Type": "application/json"
};

async function request(url, init = {}) {
  const response = await fetch(url, init);
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`${response.status} ${response.statusText}: ${text}`);
  }
  if (response.status === 204) {
    return null;
  }
  return response.json();
}

const seed = JSON.parse(await fs.readFile(seedPath, "utf8"));

await request(`${supabaseUrl}/rest/v1/standards_repository?on_conflict=standard_code`, {
  method: "POST",
  headers: {
    ...headers,
    Prefer: "resolution=merge-duplicates,return=representation"
  },
  body: JSON.stringify(seed.standards_repository)
});

const standardRows = await request(
  `${supabaseUrl}/rest/v1/standards_repository?select=id,standard_code&standard_code=in.(${seed.standards_repository
    .map((item) => item.standard_code)
    .join(",")})`,
  { headers }
);
const idByCode = new Map(standardRows.map((row) => [row.standard_code, row.id]));

await request(
  `${supabaseUrl}/rest/v1/damage_repair_mapping?damage_code=in.(${[
    ...new Set(seed.damage_repair_mapping.map((item) => item.damage_code))
  ].join(",")})`,
  {
    method: "DELETE",
    headers: {
      ...headers,
      Prefer: "return=minimal"
    }
  }
);

const mappingRows = seed.damage_repair_mapping.map((item) => {
  const standardId = idByCode.get(item.standard_code);
  if (!standardId) {
    throw new Error(`Missing standard id for ${item.standard_code}`);
  }
  const { standard_code, ...rest } = item;
  return {
    ...rest,
    standard_id: standardId
  };
});

await request(`${supabaseUrl}/rest/v1/damage_repair_mapping`, {
  method: "POST",
  headers: {
    ...headers,
    Prefer: "return=representation"
  },
  body: JSON.stringify(mappingRows)
});

const sample = await request(
  `${supabaseUrl}/rest/v1/damage_repair_mapping?damage_code=eq.B2&select=damage_code,recommended_repair_code,repair_name,standards_repository(standard_code,title)&order=recommended_repair_code.asc`,
  { headers }
);

console.log(
  JSON.stringify(
    {
      standard_count: seed.standards_repository.length,
      mapping_count: mappingRows.length,
      sample
    },
    null,
    2
  )
);
