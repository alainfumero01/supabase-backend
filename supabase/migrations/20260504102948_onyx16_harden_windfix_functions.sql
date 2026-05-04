begin;

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

commit;
