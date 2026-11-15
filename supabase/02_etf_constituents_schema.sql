-- =====================================================================
-- ETF constituents (holdings list) + returns helpers
-- Adds to the existing perf_* schema. Safe to run more than once.
-- =====================================================================

-- 1) Full holdings list per ETF and as-of date, with the TSX ticker of each company
create table if not exists etf_constituents (
  etf            text not null,
  as_of          date not null,
  company        text not null,
  category       text,
  is_equity      boolean not null default true,
  weight_pct     numeric,
  market_value   numeric,
  ticker         text,          -- plain TSX symbol, e.g. RY, BIP.UN, TECK.B
  yahoo_symbol   text,          -- e.g. RY.TO, BIP-UN.TO
  ticker_source  text,          -- known | yahoo_search | agent
  ticker_note    text,
  updated_at     timestamptz not null default now(),
  primary key (etf, as_of, company)
);
create index if not exists etf_constituents_ticker_idx on etf_constituents (ticker);
alter table etf_constituents enable row level security;

-- 2) Save a batch of holdings (JSON array). Keeps tickers already fixed by the agent.
create or replace function save_etf_constituents(p jsonb)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare n int;
begin
  insert into etf_constituents as c
    (etf, as_of, company, category, is_equity, weight_pct, market_value,
     ticker, yahoo_symbol, ticker_source, ticker_note, updated_at)
  select upper(x->>'etf'),
         (x->>'asOf')::date,
         x->>'company',
         nullif(x->>'category', ''),
         coalesce((x->>'isEquity')::boolean, true),
         case when jsonb_typeof(x->'weightPct') = 'number' then (x->>'weightPct')::numeric end,
         case when jsonb_typeof(x->'marketValue') = 'number' then (x->>'marketValue')::numeric end,
         nullif(x->>'ticker', ''),
         nullif(x->>'yahooSymbol', ''),
         nullif(x->>'tickerSource', ''),
         nullif(x->>'tickerNote', ''),
         now()
  from jsonb_array_elements(coalesce(p, '[]'::jsonb)) x
  on conflict (etf, as_of, company) do update set
    category      = excluded.category,
    is_equity     = excluded.is_equity,
    weight_pct    = excluded.weight_pct,
    market_value  = excluded.market_value,
    ticker        = case when c.ticker_source = 'agent' then c.ticker        else coalesce(excluded.ticker, c.ticker) end,
    yahoo_symbol  = case when c.ticker_source = 'agent' then c.yahoo_symbol  else coalesce(excluded.yahoo_symbol, c.yahoo_symbol) end,
    ticker_note   = case when c.ticker_source = 'agent' then c.ticker_note   else excluded.ticker_note end,
    ticker_source = case when c.ticker_source = 'agent' then c.ticker_source else coalesce(excluded.ticker_source, c.ticker_source) end,
    updated_at    = now();
  get diagnostics n = row_count;
  return n;
end;
$$;

-- 3) Tickers already known from earlier runs (company name -> ticker), agent fixes first
create or replace function get_known_tickers()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'company', company, 'ticker', ticker, 'yahooSymbol', yahoo_symbol, 'source', ticker_source)), '[]'::jsonb)
  from (
    select distinct on (company) company, ticker, yahoo_symbol, ticker_source
    from etf_constituents
    where ticker is not null or ticker_source = 'agent'
    order by company, (ticker_source = 'agent') desc, updated_at desc
  ) k;
$$;

-- 4) The agent fixes or confirms a ticker for a company (all ETFs, all dates).
--    p_ticker = plain TSX symbol (RY, BIP.UN, TECK.B) or '' to mark "no listed ticker".
create or replace function set_constituent_ticker(p_company text, p_ticker text, p_note text default null)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  t text := nullif(upper(trim(coalesce(p_ticker, ''))), '');
  y text;
  n int;
begin
  if t is not null then
    if t ~ '\.(TO|V|NE|CN)$' then
      y := t;
      t := regexp_replace(t, '\.(TO|V|NE|CN)$', '');
      t := replace(t, '-', '.');
    else
      y := replace(t, '.', '-') || '.TO';
    end if;
  end if;
  update etf_constituents
     set ticker = t, yahoo_symbol = y, ticker_source = 'agent',
         ticker_note = p_note, updated_at = now()
   where upper(company) = upper(p_company);
  get diagnostics n = row_count;
  return n;
end;
$$;

-- 5) Latest holdings list for the ETFs asked (comma-separated, empty = all)
create or replace function get_constituents(p_etfs text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with latest as (select etf, max(as_of) as as_of from etf_constituents group by etf)
  select coalesce(jsonb_agg(jsonb_build_object(
           'etf', c.etf, 'asOf', c.as_of, 'company', c.company, 'ticker', c.ticker,
           'weightPct', c.weight_pct, 'isEquity', c.is_equity, 'tickerSource', c.ticker_source)
           order by c.etf, c.weight_pct desc nulls last), '[]'::jsonb)
  from etf_constituents c
  join latest l on l.etf = c.etf and l.as_of = c.as_of
  where coalesce(trim(p_etfs), '') = ''
     or c.etf = any(string_to_array(upper(replace(p_etfs, ' ', '')), ','));
$$;

-- 6) Distinct tickers to price for the ETFs asked (latest list, equities with a ticker)
create or replace function get_tickers_to_price(p_etfs text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with latest as (select etf, max(as_of) as as_of from etf_constituents group by etf)
  select coalesce(jsonb_agg(jsonb_build_object('ticker', ticker, 'yahooSymbol', yahoo_symbol) order by ticker), '[]'::jsonb)
  from (
    select distinct c.ticker, c.yahoo_symbol
    from etf_constituents c
    join latest l on l.etf = c.etf and l.as_of = c.as_of
    where c.is_equity and c.ticker is not null and c.yahoo_symbol is not null
      and (coalesce(trim(p_etfs), '') = ''
           or c.etf = any(string_to_array(upper(replace(p_etfs, ' ', '')), ',')))
  ) t;
$$;

-- 7) Save returns rows: [{ticker, period, returnPct, totalReturnPct, toDate, priceAsOf}]
create or replace function save_returns(p jsonb)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare n int;
begin
  insert into perf_returns (ticker, period, return_pct, total_return_pct, to_date, price_as_of, updated_at)
  select upper(x->>'ticker'),
         x->>'period',
         (x->>'returnPct')::numeric,
         case when jsonb_typeof(x->'totalReturnPct') = 'number' then (x->>'totalReturnPct')::numeric end,
         coalesce((x->>'toDate')::boolean, false),
         nullif(x->>'priceAsOf', '')::date,
         now()
  from jsonb_array_elements(coalesce(p, '[]'::jsonb)) x
  where jsonb_typeof(x->'returnPct') = 'number'
  on conflict (ticker, period) do update set
    return_pct       = excluded.return_pct,
    total_return_pct = excluded.total_return_pct,
    to_date          = excluded.to_date,
    price_as_of      = excluded.price_as_of,
    updated_at       = now();
  get diagnostics n = row_count;
  return n;
end;
$$;

-- 8) Full table: every holding of the latest list with all its returns + contribution
create or replace view etf_constituent_returns as
with latest as (select etf, max(as_of) as as_of from etf_constituents group by etf)
select c.etf, c.as_of, c.company, c.ticker, c.weight_pct, c.is_equity,
       r.period, r.return_pct, r.total_return_pct, r.to_date, r.price_as_of,
       round(c.weight_pct * r.return_pct / 100, 4) as contribution_pts
from etf_constituents c
join latest l on l.etf = c.etf and l.as_of = c.as_of
left join perf_returns r on r.ticker = c.ticker;

alter view etf_constituent_returns set (security_invoker = true);

-- 9) Summary per ETF for the returns agent: coverage + top/bottom contributors
create or replace function get_returns_summary(p_etfs text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with latest as (select etf, max(as_of) as as_of from etf_constituents group by etf),
  c as (
    select c.* from etf_constituents c
    join latest l on l.etf = c.etf and l.as_of = c.as_of
    where coalesce(trim(p_etfs), '') = ''
       or c.etf = any(string_to_array(upper(replace(p_etfs, ' ', '')), ','))
  ),
  ytd_p as (select max(period) as p from perf_returns where period ~ '^\d{4}YTD$'),
  q_p   as (select max(period) as p from perf_returns where period ~ '^\d{4}Q[1-4]$' and not to_date),
  j as (
    select c.etf, c.as_of, c.company, c.ticker, c.weight_pct, c.is_equity,
           y.return_pct as ytd, q.return_pct as lq
    from c
    left join perf_returns y on y.ticker = c.ticker and y.period = (select p from ytd_p)
    left join perf_returns q on q.ticker = c.ticker and q.period = (select p from q_p)
  ),
  per_etf as (
    select j.etf, jsonb_build_object(
      'etf', j.etf,
      'asOf', max(j.as_of),
      'holdings', count(*),
      'equities', count(*) filter (where j.is_equity),
      'totalWeightPct', round(sum(j.weight_pct), 2),
      'pricedEquities', count(*) filter (where j.is_equity and j.ytd is not null),
      'pricedWeightPct', round(coalesce(sum(j.weight_pct) filter (where j.is_equity and j.ytd is not null), 0), 2),
      'approxYtdContributionPts', round(coalesce(sum(j.weight_pct * j.ytd / 100) filter (where j.ytd is not null), 0), 2),
      'approxLastQuarterContributionPts', round(coalesce(sum(j.weight_pct * j.lq / 100) filter (where j.lq is not null), 0), 2),
      'unpriced', coalesce(jsonb_agg(jsonb_build_object('company', j.company, 'ticker', j.ticker, 'weightPct', j.weight_pct)
                    order by j.weight_pct desc) filter (where j.is_equity and j.ytd is null), '[]'::jsonb),
      'topYtd', (select coalesce(jsonb_agg(t), '[]'::jsonb) from (
          select k.company, k.ticker, k.weight_pct as "weightPct", k.ytd as "returnPct",
                 round(k.weight_pct * k.ytd / 100, 3) as "contributionPts"
          from j k where k.etf = j.etf and k.ytd is not null
          order by k.weight_pct * k.ytd desc limit 5) t),
      'bottomYtd', (select coalesce(jsonb_agg(t), '[]'::jsonb) from (
          select k.company, k.ticker, k.weight_pct as "weightPct", k.ytd as "returnPct",
                 round(k.weight_pct * k.ytd / 100, 3) as "contributionPts"
          from j k where k.etf = j.etf and k.ytd is not null
          order by k.weight_pct * k.ytd asc limit 5) t),
      'topLastQuarter', (select coalesce(jsonb_agg(t), '[]'::jsonb) from (
          select k.company, k.ticker, k.weight_pct as "weightPct", k.lq as "returnPct",
                 round(k.weight_pct * k.lq / 100, 3) as "contributionPts"
          from j k where k.etf = j.etf and k.lq is not null
          order by k.weight_pct * k.lq desc limit 5) t),
      'bottomLastQuarter', (select coalesce(jsonb_agg(t), '[]'::jsonb) from (
          select k.company, k.ticker, k.weight_pct as "weightPct", k.lq as "returnPct",
                 round(k.weight_pct * k.lq / 100, 3) as "contributionPts"
          from j k where k.etf = j.etf and k.lq is not null
          order by k.weight_pct * k.lq asc limit 5) t)
    ) as e
    from j
    group by j.etf
  )
  select jsonb_build_object(
    'ytdPeriod', (select p from ytd_p),
    'lastCompleteQuarter', (select p from q_p),
    'note', 'Contribution = current weight x period return / 100. Approximation using today''s weights, not the fund''s official return.',
    'etfs', coalesce((select jsonb_agg(e order by etf) from per_etf), '[]'::jsonb)
  );
$$;

-- Keep everything off the public Supabase API
revoke execute on function save_etf_constituents(jsonb)          from public, anon, authenticated;
revoke execute on function get_known_tickers()                   from public, anon, authenticated;
revoke execute on function set_constituent_ticker(text, text, text) from public, anon, authenticated;
revoke execute on function get_constituents(text)                from public, anon, authenticated;
revoke execute on function get_tickers_to_price(text)            from public, anon, authenticated;
revoke execute on function save_returns(jsonb)                   from public, anon, authenticated;
revoke execute on function get_returns_summary(text)             from public, anon, authenticated;
revoke all on etf_constituent_returns from anon, authenticated;

-- 10) Bulk version for the agent: [{company, ticker, note}] in one call
create or replace function set_constituent_tickers(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  x jsonb;
  total int := 0;
  n int;
  nomatch jsonb := '[]'::jsonb;
begin
  for x in select * from jsonb_array_elements(coalesce(p, '[]'::jsonb)) loop
    n := set_constituent_ticker(x->>'company', x->>'ticker', x->>'note');
    total := total + n;
    if n = 0 then nomatch := nomatch || jsonb_build_array(x->>'company'); end if;
  end loop;
  return jsonb_build_object('rowsUpdated', total, 'companiesNotFound', nomatch);
end;
$$;
revoke execute on function set_constituent_tickers(jsonb) from public, anon, authenticated;
