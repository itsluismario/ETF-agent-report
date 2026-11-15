-- =====================================================================
-- ETF Performance sub-agent - Supabase schema
-- Run once in Supabase: SQL Editor > New query > paste > Run
-- =====================================================================

-- 1) One row per agent run (keeps the full JSON block and errors)
create table if not exists perf_runs (
  id           uuid primary key default gen_random_uuid(),
  run_at       timestamptz not null default now(),
  request      text,
  status       text not null check (status in ('success','partial','failed','invalid_request')),
  price_as_of  date,
  errors       jsonb not null default '[]'::jsonb,
  payload      jsonb not null
);

-- 2) Per-ETF metadata for each run (source, as-of date, coverage)
create table if not exists perf_etf_snapshots (
  run_id          uuid not null references perf_runs(id) on delete cascade,
  etf             text not null,
  as_of           date,
  source_url      text,
  holdings_count  int,
  coverage_pct    numeric,
  primary key (run_id, etf)
);

-- 3) Holdings and weights for each run
--    (for FCCA the "tickers" are FCCL, FCCV, FCCQ, FCCM)
create table if not exists perf_holdings (
  run_id      uuid not null references perf_runs(id) on delete cascade,
  etf         text not null,
  ticker      text not null,
  company     text,
  weight_pct  numeric,
  primary key (run_id, etf, ticker)
);

-- 4) Returns per ticker and period, deduplicated across runs
--    period examples: '2025Q1', '2025', '2026Q4', '2026YTD'
create table if not exists perf_returns (
  ticker            text not null,
  period            text not null,
  return_pct        numeric,
  total_return_pct  numeric,
  to_date           boolean not null default false,
  price_as_of       date,
  updated_at        timestamptz not null default now(),
  primary key (ticker, period)
);

-- 5) Contributions (pts) per ETF, ticker and period for each run
create table if not exists perf_contributions (
  run_id            uuid not null references perf_runs(id) on delete cascade,
  etf               text not null,
  ticker            text not null,
  period            text not null,
  contribution_pts  numeric,
  primary key (run_id, etf, ticker, period)
);

create index if not exists perf_runs_run_at_idx on perf_runs (run_at desc);
create index if not exists perf_holdings_ticker_idx on perf_holdings (ticker);

-- ---------------------------------------------------------------------
-- Save function: the agent sends its whole JSON block, the DB splits it
-- ---------------------------------------------------------------------
create or replace function save_performance_run(p jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_run uuid;
  h     jsonb;
  k     text;
  v     jsonb;
begin
  insert into perf_runs (request, status, price_as_of, errors, payload)
  values (
    p->>'request',
    coalesce(p->>'status', 'failed'),
    nullif(p->>'priceAsOf', '')::date,
    coalesce(p->'errors', '[]'::jsonb),
    p
  )
  returning id into v_run;

  insert into perf_etf_snapshots (run_id, etf, as_of, source_url, holdings_count, coverage_pct)
  select v_run,
         e->>'etf',
         nullif(e->>'asOf', '')::date,
         e->>'sourceUrl',
         nullif(e->>'holdingsCount', '')::int,
         nullif(e->>'coveragePct', '')::numeric
  from jsonb_array_elements(coalesce(p->'etfs', '[]'::jsonb)) e
  on conflict do nothing;

  for h in select * from jsonb_array_elements(coalesce(p->'holdings', '[]'::jsonb)) loop

    insert into perf_holdings (run_id, etf, ticker, company, weight_pct)
    values (v_run, h->>'etf', upper(h->>'ticker'), h->>'company', nullif(h->>'weightPct', '')::numeric)
    on conflict do nothing;

    -- quarterly + annual returns -> perf_returns (skip nulls so good data is never overwritten)
    for k, v in
      select * from jsonb_each(coalesce(h->'quarterly', '{}'::jsonb) || coalesce(h->'annual', '{}'::jsonb))
    loop
      if jsonb_typeof(v) = 'object' and jsonb_typeof(v->'returnPct') = 'number' then
        insert into perf_returns (ticker, period, return_pct, total_return_pct, to_date, price_as_of)
        values (
          upper(h->>'ticker'),
          k,
          (v->>'returnPct')::numeric,
          case when jsonb_typeof(v->'totalReturnPct') = 'number' then (v->>'totalReturnPct')::numeric end,
          coalesce((v->>'toDate')::boolean, false),
          nullif(p->>'priceAsOf', '')::date
        )
        on conflict (ticker, period) do update
          set return_pct       = excluded.return_pct,
              total_return_pct = excluded.total_return_pct,
              to_date          = excluded.to_date,
              price_as_of      = excluded.price_as_of,
              updated_at       = now();
      end if;
    end loop;

    -- contributions -> perf_contributions
    for k, v in select * from jsonb_each(coalesce(h->'contributions', '{}'::jsonb)) loop
      if jsonb_typeof(v) = 'number' then
        insert into perf_contributions (run_id, etf, ticker, period, contribution_pts)
        values (v_run, h->>'etf', upper(h->>'ticker'), k, (v #>> '{}')::numeric)
        on conflict do nothing;
      end if;
    end loop;

  end loop;

  return v_run;
end;
$$;

-- ---------------------------------------------------------------------
-- Handy views for reports / the news sub-agent
-- ---------------------------------------------------------------------

-- Latest run id
create or replace view perf_latest_run as
select id as run_id, run_at, status
from perf_runs
where status in ('success', 'partial')
order by run_at desc
limit 1;

-- FCCA look-through company weights (computed in SQL, per run)
create or replace view perf_fcca_lookthrough as
select f.run_id,
       u.ticker,
       max(u.company) as company,
       round(sum(f.weight_pct * u.weight_pct / 100), 4) as lookthrough_weight_pct
from perf_holdings f
join perf_holdings u
  on u.run_id = f.run_id
 and u.etf = upper(f.ticker)
where f.etf = 'FCCA'
group by f.run_id, u.ticker;

-- Same company across several ETFs (latest run)
create or replace view perf_cross_etf as
select h.ticker,
       max(h.company) as company,
       jsonb_object_agg(h.etf, h.weight_pct) as weight_by_etf,
       count(*) as etf_count
from perf_holdings h
join perf_latest_run l on l.run_id = h.run_id
where h.etf <> 'FCCA'
group by h.ticker
having count(*) > 1;

-- ---------------------------------------------------------------------
-- Security: block the public Supabase API; n8n connects as postgres
-- (postgres bypasses RLS, anon/authenticated get nothing)
-- ---------------------------------------------------------------------
alter table perf_runs           enable row level security;
alter table perf_etf_snapshots  enable row level security;
alter table perf_holdings       enable row level security;
alter table perf_returns        enable row level security;
alter table perf_contributions  enable row level security;

revoke execute on function save_performance_run(jsonb) from public, anon, authenticated;

-- Views: respect table RLS and hide them from the public API
alter view perf_latest_run       set (security_invoker = true);
alter view perf_fcca_lookthrough set (security_invoker = true);
alter view perf_cross_etf        set (security_invoker = true);
revoke all on perf_latest_run, perf_fcca_lookthrough, perf_cross_etf from anon, authenticated;

-- Views ignore RLS by default in Supabase: make them respect it and hide them from the public API
alter view perf_cross_etf        set (security_invoker = true);
alter view perf_fcca_lookthrough set (security_invoker = true);
alter view perf_latest_run       set (security_invoker = true);
revoke select on perf_cross_etf, perf_fcca_lookthrough, perf_latest_run from anon, authenticated;
