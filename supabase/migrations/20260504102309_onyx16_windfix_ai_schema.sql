begin;

create schema if not exists app_private;

create or replace function app_private.ensure_case_client_consistency()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  work_order_client_id uuid;
begin
  select client_id
    into work_order_client_id
  from public.work_orders
  where id = new.work_order_id;

  if work_order_client_id is null then
    raise exception 'work_order % is missing or does not have a client_id', new.work_order_id;
  end if;

  if new.client_id <> work_order_client_id then
    raise exception 'case client_id % must match work_order client_id %', new.client_id, work_order_client_id;
  end if;

  return new;
end;
$$;

create or replace function app_private.ensure_quote_case_consistency()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  case_work_order_id uuid;
  case_client_id uuid;
begin
  select work_order_id, client_id
    into case_work_order_id, case_client_id
  from public.cases
  where id = new.case_id;

  if case_work_order_id is null or case_client_id is null then
    raise exception 'case % is missing or incomplete', new.case_id;
  end if;

  if new.work_order_id <> case_work_order_id then
    raise exception 'quote work_order_id % must match case work_order_id %', new.work_order_id, case_work_order_id;
  end if;

  if new.client_id <> case_client_id then
    raise exception 'quote client_id % must match case client_id %', new.client_id, case_client_id;
  end if;

  return new;
end;
$$;

create or replace function app_private.ensure_repair_documentation_case_consistency()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  case_work_order_id uuid;
  quote_case_id uuid;
begin
  select work_order_id
    into case_work_order_id
  from public.cases
  where id = new.case_id;

  if case_work_order_id is null then
    raise exception 'case % is missing or incomplete', new.case_id;
  end if;

  if new.work_order_id <> case_work_order_id then
    raise exception 'repair_documentation work_order_id % must match case work_order_id %', new.work_order_id, case_work_order_id;
  end if;

  if new.quote_id is not null then
    select case_id
      into quote_case_id
    from public.quotes
    where id = new.quote_id;

    if quote_case_id is distinct from new.case_id then
      raise exception 'repair_documentation quote % must belong to case %', new.quote_id, new.case_id;
    end if;
  end if;

  return new;
end;
$$;

create or replace function app_private.ensure_final_report_case_consistency()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  case_work_order_id uuid;
  quote_case_id uuid;
  repair_case_id uuid;
begin
  select work_order_id
    into case_work_order_id
  from public.cases
  where id = new.case_id;

  if case_work_order_id is null then
    raise exception 'case % is missing or incomplete', new.case_id;
  end if;

  if new.work_order_id <> case_work_order_id then
    raise exception 'final_report work_order_id % must match case work_order_id %', new.work_order_id, case_work_order_id;
  end if;

  if new.quote_id is not null then
    select case_id
      into quote_case_id
    from public.quotes
    where id = new.quote_id;

    if quote_case_id is distinct from new.case_id then
      raise exception 'final_report quote % must belong to case %', new.quote_id, new.case_id;
    end if;
  end if;

  if new.repair_documentation_id is not null then
    select case_id
      into repair_case_id
    from public.repair_documentation
    where id = new.repair_documentation_id;

    if repair_case_id is distinct from new.case_id then
      raise exception 'final_report repair_documentation % must belong to case %', new.repair_documentation_id, new.case_id;
    end if;
  end if;

  return new;
end;
$$;

create table if not exists public.cases (
  id uuid primary key default gen_random_uuid(),
  case_number text not null unique,
  work_order_id uuid not null references public.work_orders (id) on delete restrict,
  client_id uuid not null references public.clients (id) on delete restrict,
  opened_by_employee_id uuid references public.employees (id) on delete set null,
  lead_employee_id uuid references public.employees (id) on delete set null,
  qa_owner_employee_id uuid references public.employees (id) on delete set null,
  created_by_user_id uuid references public.users (id) on delete set null,
  updated_by_user_id uuid references public.users (id) on delete set null,
  title text not null,
  description text,
  case_type text not null default 'inspection' check (case_type in ('inspection', 'repair', 'warranty', 'quality', 'other')),
  status text not null default 'draft' check (
    status in (
      'draft',
      'intake',
      'triage',
      'inspection',
      'analysis',
      'quote_preparation',
      'quote_pending_approval',
      'approved_for_repair',
      'repair_in_progress',
      'qa_review',
      'finalized',
      'archived',
      'cancelled'
    )
  ),
  priority text not null default 'normal' check (priority in ('low', 'normal', 'high', 'critical')),
  intake_source text,
  external_reference text,
  opened_at timestamptz not null default timezone('utc', now()),
  closed_at timestamptz,
  archived_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (closed_at is null or closed_at >= opened_at),
  check (archived_at is null or archived_at >= opened_at)
);

create table if not exists public.case_images (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.cases (id) on delete cascade,
  uploaded_by_employee_id uuid references public.employees (id) on delete set null,
  image_role text not null default 'intake' check (image_role in ('intake', 'inspection', 'repair', 'qa', 'final_report', 'other')),
  storage_bucket text not null default 'onyx-assets',
  storage_path text not null unique,
  file_name text not null,
  mime_type text not null,
  file_size_bytes bigint check (file_size_bytes is null or file_size_bytes > 0),
  captured_at timestamptz not null,
  captured_latitude numeric(9,6),
  captured_longitude numeric(9,6),
  gps_accuracy_meters numeric(8,2) check (gps_accuracy_meters is null or gps_accuracy_meters >= 0),
  camera_make text,
  camera_model text,
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (
    (captured_latitude is null and captured_longitude is null)
    or (captured_latitude is not null and captured_longitude is not null)
  ),
  check (captured_latitude is null or captured_latitude between -90 and 90),
  check (captured_longitude is null or captured_longitude between -180 and 180)
);

create table if not exists public.damage_detections (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.cases (id) on delete cascade,
  case_image_id uuid references public.case_images (id) on delete set null,
  detected_by text not null default 'ai' check (detected_by in ('ai', 'human', 'hybrid')),
  damage_code text not null,
  damage_category text not null,
  damage_label text not null,
  severity_level text not null default 'medium' check (severity_level in ('low', 'medium', 'high', 'critical')),
  severity_score numeric(5,4) check (severity_score is null or (severity_score >= 0 and severity_score <= 1)),
  confidence_score numeric(5,4) check (confidence_score is null or (confidence_score >= 0 and confidence_score <= 1)),
  bounding_box jsonb,
  segmentation_mask_uri text,
  detection_status text not null default 'pending_review' check (detection_status in ('pending_review', 'confirmed', 'rejected', 'resolved')),
  detected_at timestamptz not null default timezone('utc', now()),
  reviewed_by_employee_id uuid references public.employees (id) on delete set null,
  reviewed_at timestamptz,
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (reviewed_at is null or reviewed_at >= detected_at)
);

create table if not exists public.standards_repository (
  id uuid primary key default gen_random_uuid(),
  standard_code text not null unique,
  title text not null,
  standard_type text not null check (standard_type in ('manufacturer', 'regulatory', 'internal', 'customer', 'safety', 'quality', 'repair')),
  issuing_body text,
  version_label text not null default '1.0',
  effective_on date,
  superseded_by_standard_id uuid references public.standards_repository (id) on delete set null,
  summary text,
  requirements jsonb not null default '[]'::jsonb,
  document_uri text,
  is_active boolean not null default true,
  created_by_user_id uuid references public.users (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.damage_repair_mapping (
  id uuid primary key default gen_random_uuid(),
  damage_code text not null,
  damage_category text not null,
  recommended_repair_code text not null,
  repair_name text not null,
  standard_id uuid not null references public.standards_repository (id) on delete restrict,
  default_scope text,
  min_severity_score numeric(5,4) check (min_severity_score is null or (min_severity_score >= 0 and min_severity_score <= 1)),
  max_severity_score numeric(5,4) check (max_severity_score is null or (max_severity_score >= 0 and max_severity_score <= 1)),
  estimated_labor_hours numeric(8,2) check (estimated_labor_hours is null or estimated_labor_hours >= 0),
  estimated_material_cost numeric(12,2) check (estimated_material_cost is null or estimated_material_cost >= 0),
  approval_required boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (damage_code, recommended_repair_code, standard_id),
  check (max_severity_score is null or min_severity_score is null or max_severity_score >= min_severity_score)
);

create table if not exists public.repair_recommendations (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.cases (id) on delete cascade,
  damage_detection_id uuid references public.damage_detections (id) on delete set null,
  mapping_id uuid references public.damage_repair_mapping (id) on delete set null,
  standard_id uuid references public.standards_repository (id) on delete set null,
  recommended_by text not null default 'ai' check (recommended_by in ('ai', 'human', 'hybrid')),
  recommendation_status text not null default 'draft' check (recommendation_status in ('draft', 'pending_review', 'approved', 'rejected', 'implemented')),
  repair_code text not null,
  repair_name text not null,
  repair_scope text,
  rationale text,
  estimated_labor_hours numeric(8,2) check (estimated_labor_hours is null or estimated_labor_hours >= 0),
  estimated_material_cost numeric(12,2) check (estimated_material_cost is null or estimated_material_cost >= 0),
  estimated_duration_hours numeric(8,2) check (estimated_duration_hours is null or estimated_duration_hours >= 0),
  requires_engineering_review boolean not null default false,
  reviewed_by_employee_id uuid references public.employees (id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.quotes (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.cases (id) on delete cascade,
  work_order_id uuid not null references public.work_orders (id) on delete restrict,
  client_id uuid not null references public.clients (id) on delete restrict,
  prepared_by_employee_id uuid references public.employees (id) on delete set null,
  quote_number text not null unique,
  status text not null default 'draft' check (status in ('draft', 'pending_internal_review', 'pending_client_approval', 'approved', 'rejected', 'expired', 'superseded')),
  currency_code text not null default 'USD' check (char_length(currency_code) = 3),
  subtotal_amount numeric(14,2) not null default 0 check (subtotal_amount >= 0),
  tax_amount numeric(14,2) not null default 0 check (tax_amount >= 0),
  total_amount numeric(14,2) not null default 0 check (total_amount >= 0),
  valid_until date,
  scope_summary text,
  assumptions text,
  exclusions text,
  prepared_at timestamptz not null default timezone('utc', now()),
  client_response_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (client_response_at is null or client_response_at >= prepared_at)
);

create table if not exists public.quote_line_items (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.quotes (id) on delete cascade,
  recommendation_id uuid references public.repair_recommendations (id) on delete set null,
  standard_id uuid references public.standards_repository (id) on delete set null,
  line_number integer not null check (line_number > 0),
  line_type text not null default 'repair' check (line_type in ('repair', 'material', 'labor', 'equipment', 'travel', 'fee', 'discount', 'other')),
  item_code text,
  description text not null,
  quantity numeric(12,2) not null check (quantity > 0),
  unit_of_measure text not null default 'ea',
  unit_price numeric(14,2) not null check (unit_price >= 0),
  total_price numeric(14,2) not null check (total_price >= 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (quote_id, line_number)
);

create table if not exists public.quote_approvals (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.quotes (id) on delete cascade,
  approver_employee_id uuid references public.employees (id) on delete set null,
  approver_name text not null,
  approver_email text,
  decision_role text not null check (decision_role in ('internal', 'client', 'finance', 'operations')),
  decision text not null check (decision in ('approved', 'rejected', 'changes_requested')),
  notes text,
  decided_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (quote_id, approver_name, decision_role)
);

create table if not exists public.repair_documentation (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.cases (id) on delete cascade,
  work_order_id uuid not null references public.work_orders (id) on delete restrict,
  quote_id uuid references public.quotes (id) on delete set null,
  lead_technician_employee_id uuid references public.employees (id) on delete set null,
  documentation_status text not null default 'draft' check (documentation_status in ('draft', 'in_progress', 'ready_for_qa', 'accepted', 'rejected')),
  repair_started_at timestamptz,
  repair_completed_at timestamptz,
  repair_method_code text,
  repair_summary text,
  materials_summary text,
  ambient_conditions jsonb,
  deviations text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (repair_completed_at is null or repair_started_at is null or repair_completed_at >= repair_started_at)
);

create table if not exists public.repair_images (
  id uuid primary key default gen_random_uuid(),
  repair_documentation_id uuid not null references public.repair_documentation (id) on delete cascade,
  captured_by_employee_id uuid references public.employees (id) on delete set null,
  image_role text not null default 'during_repair' check (image_role in ('before_repair', 'during_repair', 'after_repair', 'qa', 'attachment', 'other')),
  storage_bucket text not null default 'onyx-assets',
  storage_path text not null unique,
  file_name text not null,
  mime_type text not null,
  file_size_bytes bigint check (file_size_bytes is null or file_size_bytes > 0),
  captured_at timestamptz not null,
  captured_latitude numeric(9,6),
  captured_longitude numeric(9,6),
  gps_accuracy_meters numeric(8,2) check (gps_accuracy_meters is null or gps_accuracy_meters >= 0),
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (
    (captured_latitude is null and captured_longitude is null)
    or (captured_latitude is not null and captured_longitude is not null)
  ),
  check (captured_latitude is null or captured_latitude between -90 and 90),
  check (captured_longitude is null or captured_longitude between -180 and 180)
);

create table if not exists public.field_documentation (
  id uuid primary key default gen_random_uuid(),
  repair_documentation_id uuid not null references public.repair_documentation (id) on delete cascade,
  case_id uuid not null references public.cases (id) on delete cascade,
  recorded_by_employee_id uuid references public.employees (id) on delete set null,
  record_type text not null check (record_type in ('materials', 'cure', 'salt_test', 'environmental', 'inspection')),
  recorded_at timestamptz not null default timezone('utc', now()),
  material_batch_numbers jsonb,
  material_mix_ratio text,
  cure_start_at timestamptz,
  cure_end_at timestamptz,
  surface_temperature_c numeric(6,2),
  ambient_temperature_c numeric(6,2),
  humidity_percent numeric(5,2) check (humidity_percent is null or (humidity_percent >= 0 and humidity_percent <= 100)),
  salt_test_result numeric(8,2),
  salt_test_unit text,
  meets_spec boolean,
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (cure_end_at is null or cure_start_at is null or cure_end_at >= cure_start_at)
);

create table if not exists public.final_reports (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.cases (id) on delete cascade,
  work_order_id uuid not null references public.work_orders (id) on delete restrict,
  quote_id uuid references public.quotes (id) on delete set null,
  repair_documentation_id uuid references public.repair_documentation (id) on delete set null,
  authored_by_employee_id uuid references public.employees (id) on delete set null,
  reviewed_by_employee_id uuid references public.employees (id) on delete set null,
  report_number text not null unique,
  version_number integer not null default 1 check (version_number > 0),
  status text not null default 'draft' check (status in ('draft', 'pending_signature', 'signed', 'issued', 'archived')),
  executive_summary text,
  findings text,
  standards_applied jsonb not null default '[]'::jsonb,
  archival_reference text,
  issued_at timestamptz,
  archived_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (case_id, version_number),
  check (archived_at is null or issued_at is null or archived_at >= issued_at)
);

create table if not exists public.report_signatures (
  id uuid primary key default gen_random_uuid(),
  final_report_id uuid not null references public.final_reports (id) on delete cascade,
  employee_id uuid references public.employees (id) on delete set null,
  signer_name text not null,
  signer_email text,
  signer_role text not null,
  signature_status text not null default 'pending' check (signature_status in ('pending', 'signed', 'declined')),
  signature_provider text,
  signed_at timestamptz,
  ip_address inet,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (final_report_id, signer_name, signer_role)
);

create table if not exists public.ai_qa_reports (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.cases (id) on delete cascade,
  qa_stage text not null check (qa_stage in ('detection', 'quote', 'repair', 'report')),
  subject_table text,
  subject_id uuid,
  generated_by text not null default 'ai' check (generated_by in ('ai', 'human', 'hybrid')),
  overall_result text not null default 'pass' check (overall_result in ('pass', 'fail', 'warning', 'needs_review')),
  completeness_score numeric(5,4) check (completeness_score is null or (completeness_score >= 0 and completeness_score <= 1)),
  compliance_score numeric(5,4) check (compliance_score is null or (compliance_score >= 0 and compliance_score <= 1)),
  findings jsonb not null default '[]'::jsonb,
  recommended_actions jsonb not null default '[]'::jsonb,
  reviewed_by_employee_id uuid references public.employees (id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_cases_work_order_status on public.cases (work_order_id, status);
create index if not exists idx_cases_client_id on public.cases (client_id);
create index if not exists idx_cases_lead_employee_id on public.cases (lead_employee_id);
create index if not exists idx_cases_qa_owner_employee_id on public.cases (qa_owner_employee_id);
create index if not exists idx_case_images_case_id on public.case_images (case_id);
create index if not exists idx_case_images_uploaded_by_employee_id on public.case_images (uploaded_by_employee_id);
create index if not exists idx_case_images_captured_at on public.case_images (captured_at desc);
create index if not exists idx_damage_detections_case_id on public.damage_detections (case_id);
create index if not exists idx_damage_detections_case_image_id on public.damage_detections (case_image_id);
create index if not exists idx_damage_detections_status on public.damage_detections (detection_status);
create index if not exists idx_standards_repository_type_active on public.standards_repository (standard_type, is_active);
create index if not exists idx_damage_repair_mapping_standard_id on public.damage_repair_mapping (standard_id);
create index if not exists idx_damage_repair_mapping_damage_code on public.damage_repair_mapping (damage_code);
create index if not exists idx_repair_recommendations_case_id on public.repair_recommendations (case_id);
create index if not exists idx_repair_recommendations_detection_id on public.repair_recommendations (damage_detection_id);
create index if not exists idx_repair_recommendations_standard_id on public.repair_recommendations (standard_id);
create index if not exists idx_quotes_case_id on public.quotes (case_id);
create index if not exists idx_quotes_work_order_id on public.quotes (work_order_id);
create index if not exists idx_quotes_client_id on public.quotes (client_id);
create index if not exists idx_quotes_status on public.quotes (status);
create index if not exists idx_quote_line_items_quote_id on public.quote_line_items (quote_id);
create index if not exists idx_quote_line_items_recommendation_id on public.quote_line_items (recommendation_id);
create index if not exists idx_quote_approvals_quote_id on public.quote_approvals (quote_id);
create index if not exists idx_quote_approvals_employee_id on public.quote_approvals (approver_employee_id);
create index if not exists idx_repair_documentation_case_id on public.repair_documentation (case_id);
create index if not exists idx_repair_documentation_work_order_id on public.repair_documentation (work_order_id);
create index if not exists idx_repair_documentation_quote_id on public.repair_documentation (quote_id);
create index if not exists idx_repair_images_repair_documentation_id on public.repair_images (repair_documentation_id);
create index if not exists idx_repair_images_captured_by_employee_id on public.repair_images (captured_by_employee_id);
create index if not exists idx_repair_images_captured_at on public.repair_images (captured_at desc);
create index if not exists idx_field_documentation_repair_documentation_id on public.field_documentation (repair_documentation_id);
create index if not exists idx_field_documentation_case_id on public.field_documentation (case_id);
create index if not exists idx_field_documentation_record_type on public.field_documentation (record_type);
create index if not exists idx_final_reports_case_id on public.final_reports (case_id);
create index if not exists idx_final_reports_work_order_id on public.final_reports (work_order_id);
create index if not exists idx_final_reports_quote_id on public.final_reports (quote_id);
create index if not exists idx_final_reports_repair_documentation_id on public.final_reports (repair_documentation_id);
create index if not exists idx_report_signatures_final_report_id on public.report_signatures (final_report_id);
create index if not exists idx_report_signatures_employee_id on public.report_signatures (employee_id);
create index if not exists idx_ai_qa_reports_case_id on public.ai_qa_reports (case_id);
create index if not exists idx_ai_qa_reports_stage on public.ai_qa_reports (qa_stage);
create index if not exists idx_ai_qa_reports_subject on public.ai_qa_reports (subject_table, subject_id);

insert into public.roles (code, name, description)
values
  ('windfix_case_manager', 'Windfix Case Manager', 'Manages Windfix case intake, workflow progression, and archival.'),
  ('windfix_field_technician', 'Windfix Field Technician', 'Captures field evidence, repair documentation, and cure or salt-test records.'),
  ('windfix_quote_approver', 'Windfix Quote Approver', 'Reviews and approves Windfix commercial quote outputs.'),
  ('windfix_qa_reviewer', 'Windfix QA Reviewer', 'Reviews AI detections, QA reports, and final report readiness.')
on conflict (code) do nothing;

do $$
declare
  tbl text;
begin
  foreach tbl in array array[
    'cases',
    'case_images',
    'damage_detections',
    'repair_recommendations',
    'ai_qa_reports',
    'quotes',
    'quote_line_items',
    'quote_approvals',
    'repair_documentation',
    'repair_images',
    'field_documentation',
    'final_reports',
    'report_signatures',
    'standards_repository',
    'damage_repair_mapping'
  ]
  loop
    execute format('alter table public.%I enable row level security', tbl);
    execute format('alter table public.%I force row level security', tbl);
  end loop;
end
$$;

do $$
declare
  tbl text;
begin
  foreach tbl in array array[
    'cases',
    'case_images',
    'damage_detections',
    'repair_recommendations',
    'ai_qa_reports',
    'quotes',
    'quote_line_items',
    'quote_approvals',
    'repair_documentation',
    'repair_images',
    'field_documentation',
    'final_reports',
    'report_signatures',
    'standards_repository',
    'damage_repair_mapping'
  ]
  loop
    execute format('drop trigger if exists set_%I_updated_at on public.%I', tbl, tbl);
    execute format(
      'create trigger set_%I_updated_at before update on public.%I for each row execute function app_private.touch_updated_at()',
      tbl,
      tbl
    );
  end loop;
end
$$;

drop trigger if exists ensure_case_client_consistency on public.cases;
create trigger ensure_case_client_consistency
before insert or update on public.cases
for each row
execute function app_private.ensure_case_client_consistency();

drop trigger if exists ensure_quote_case_consistency on public.quotes;
create trigger ensure_quote_case_consistency
before insert or update on public.quotes
for each row
execute function app_private.ensure_quote_case_consistency();

drop trigger if exists ensure_repair_documentation_case_consistency on public.repair_documentation;
create trigger ensure_repair_documentation_case_consistency
before insert or update on public.repair_documentation
for each row
execute function app_private.ensure_repair_documentation_case_consistency();

drop trigger if exists ensure_final_report_case_consistency on public.final_reports;
create trigger ensure_final_report_case_consistency
before insert or update on public.final_reports
for each row
execute function app_private.ensure_final_report_case_consistency();

comment on table public.cases is 'Windfix AI case record linking case workflow to ERP work orders, clients, and assigned employees.';
comment on table public.case_images is 'Geo-tagged and time-stamped field imagery captured during intake, inspection, repair, and reporting stages.';
comment on table public.damage_detections is 'AI or human-confirmed damage observations derived from case imagery.';
comment on table public.repair_recommendations is 'Repair actions proposed from damage detections and standards mappings.';
comment on table public.ai_qa_reports is 'QA outputs that score completeness and compliance of Windfix artifacts across workflow stages.';
comment on table public.quotes is 'Commercial quote headers generated from approved Windfix repair recommendations.';
comment on table public.quote_approvals is 'Approval decisions for Windfix quotes, supporting both internal and client reviewers.';
comment on table public.repair_documentation is 'Narrative and structured execution record for the performed repair work.';
comment on table public.field_documentation is 'Structured field logs for materials, cure windows, salt testing, and environmental observations.';
comment on table public.final_reports is 'Customer-facing closeout reports and ERP archival references for completed Windfix cases.';
comment on table public.standards_repository is 'Reference catalog of manufacturer, regulatory, and internal standards used by Windfix decisions.';
comment on table public.damage_repair_mapping is 'Mapping layer between detected damage patterns, recommended repairs, and the governing standard.';

commit;
