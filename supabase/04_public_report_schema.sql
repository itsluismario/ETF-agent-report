-- =====================================================================
-- Public read-only report for the Netlify site (etf-agent-report)
-- Only get_public_report() is callable with the public (anon) key.
-- =====================================================================

create table if not exists report_runs (
  id          bigserial primary key,
  created_at  timestamptz not null default now(),
  request     text,
  summary     text not null
);
alter table report_runs enable row level security;

create or replace function save_report_run(p_request text, p_summary text)
returns bigint
language sql
security definer
set search_path = public
as $$
  insert into report_runs (request, summary) values (p_request, p_summary) returning id;
$$;

create or replace function get_public_report()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'generatedAt', now(),
    'latestReport', (select jsonb_build_object('createdAt', created_at, 'summary', summary)
                     from report_runs order by created_at desc limit 1),
    'pricing', get_price_status(),
    'highlights', get_returns_summary(''),
    'etfs', coalesce((
      select jsonb_agg(jsonb_build_object(
               'etf', e.etf,
               'asOf', (select max(as_of) from etf_constituents c where c.etf = e.etf),
               'sourceUrl', 'https://www.fidelity.ca/en/products/etfs/' || lower(e.etf) || '/',
               'rows', get_returns_table(e.etf))
             order by e.etf)
      from (select distinct etf from etf_constituents) e), '[]'::jsonb)
  );
$$;

revoke execute on function save_report_run(text, text) from public, anon, authenticated;
revoke execute on function get_public_report() from public;
grant  execute on function get_public_report() to anon, authenticated;
