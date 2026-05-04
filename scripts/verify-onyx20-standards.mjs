const supabaseUrl = process.env.SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required.");
}

const headers = {
  apikey: serviceRoleKey,
  Authorization: `Bearer ${serviceRoleKey}`
};

async function getJson(url) {
  const response = await fetch(url, { headers });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`${response.status} ${response.statusText}: ${text}`);
  }
  return response.json();
}

const standards = await getJson(
  `${supabaseUrl}/rest/v1/standards_repository?select=standard_code,requirements&order=standard_code.asc`
);
const mappings = await getJson(
  `${supabaseUrl}/rest/v1/damage_repair_mapping?select=damage_code,recommended_repair_code,standard_id`
);
const sampleB2 = await getJson(
  `${supabaseUrl}/rest/v1/damage_repair_mapping?damage_code=eq.B2&select=damage_code,recommended_repair_code,repair_name,standards_repository(standard_code,title)&order=recommended_repair_code.asc`
);

const a4Excerpts = standards.flatMap((standard) =>
  standard.requirements
    .filter((requirement) => requirement.damage_codes.includes("A4"))
    .map((requirement) => ({
      standard_code: standard.standard_code,
      citation: requirement.citation
    }))
);

console.log(
  JSON.stringify(
    {
      standard_count: standards.length,
      distinct_damage_codes: [...new Set(mappings.map((row) => row.damage_code))].length,
      mapping_count: mappings.length,
      a4_excerpt_count: a4Excerpts.length,
      a4_excerpts: a4Excerpts,
      sample_b2: sampleB2
    },
    null,
    2
  )
);
