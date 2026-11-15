-- =====================================================================
-- Monthly prices (Alpha Vantage, TIME_SERIES_MONTHLY_ADJUSTED) -> returns
-- Safe to run more than once.
-- =====================================================================

create table if not exists price_monthly (
  ticker      text not null,          -- plain TSX ticker, e.g. RY, BIP.UN
  month_end   date not null,          -- last trading day of the month (or latest day for the current month)
  close       numeric not null,
  adj_close   numeric,                -- dividend/split adjusted close
  source      text not null default 'alphavantage',
  updated_at  timestamptz not null default now(),
  primary key (ticker, month_end)
);
alter table price_monthly enable row level security;

create table if not exists price_fetch_log (
  ticker        text primary key,
  last_attempt  timestamptz,
  last_success  timestamptz,
  status        text,                 -- ok | error
  message       text,
  av_symbol     text
);
alter table price_fetch_log enable row level security;

-- Next tickers to price: never tried first, then oldest success; skip ones priced in the last 20 days (monthly cycle).
create or replace function get_tickers_to_fetch(p_limit int)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with latest as (select etf, max(as_of) as as_of from etf_constituents group by etf),
  t as (
    select c.ticker, max(c.weight_pct) as max_w
    from etf_constituents c
    join latest l on l.etf = c.etf and l.as_of = c.as_of
    where c.is_equity and c.ticker is not null
    group by c.ticker
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'ticker', t.ticker,
           'avSymbol', replace(t.ticker, '.', '-') || '.TRT')
         order by t.last_attempt asc nulls first, t.max_w desc), '[]'::jsonb)
  from (
    select t.*, g.last_attempt
    from t left join price_fetch_log g on g.ticker = t.ticker
    where (g.last_success is null or g.last_success < now() - interval '20 days')
      and (g.last_attempt is null or g.last_attempt < now() - interval '20 hours')
    order by g.last_attempt asc nulls first, t.max_w desc
    limit greatest(coalesce(p_limit, 24), 0)
  ) t;
$$;

-- Save prices + log. p = {"prices":[{ticker,monthEnd,close,adjClose}], "log":[{ticker,avSymbol,status,message}]}
create or replace function save_monthly_prices(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare n_prices int; n_log int;
begin
  insert into price_monthly as m (ticker, month_end, close, adj_close, updated_at)
  select upper(x->>'ticker'), (x->>'monthEnd')::date, (x->>'close')::numeric,
         case when jsonb_typeof(x->'adjClose') = 'number' then (x->>'adjClose')::numeric end, now()
  from jsonb_array_elements(coalesce(p->'prices', '[]'::jsonb)) x
  where jsonb_typeof(x->'close') = 'number'
  on conflict (ticker, month_end) do update
    set close = excluded.close, adj_close = excluded.adj_close, updated_at = now();
  get diagnostics n_prices = row_count;

  -- a fresh partial month replaces the previous partial row of the same month
  delete from price_monthly m
  using (select upper(x->>'ticker') as ticker, (x->>'monthEnd')::date as d
         from jsonb_array_elements(coalesce(p->'prices', '[]'::jsonb)) x) n
  where m.ticker = n.ticker
    and date_trunc('month', m.month_end) = date_trunc('month', n.d)
    and m.month_end < n.d;

  insert into price_fetch_log as g (ticker, last_attempt, last_success, status, message, av_symbol)
  select upper(x->>'ticker'), now(),
         case when x->>'status' = 'ok' then now() end,
         x->>'status', left(x->>'message', 300), x->>'avSymbol'
  from jsonb_array_elements(coalesce(p->'log', '[]'::jsonb)) x
  on conflict (ticker) do update set
    last_attempt = excluded.last_attempt,
    last_success = coalesce(excluded.last_success, g.last_success),
    status = excluded.status, message = excluded.message, av_symbol = excluded.av_symbol;
  get diagnostics n_log = row_count;

  return jsonb_build_object('pricesSaved', n_prices, 'logged', n_log);
end;
$$;

-- Rebuild quarterly / annual / YTD returns from month-end closes (last 4 calendar years)
create or replace function refresh_returns_from_prices()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare n int;
begin
  with base as (
    select ticker, month_end, close, coalesce(adj_close, close) as adj,
           coalesce(adj_close, close) / close as f
    from price_monthly
    where month_end >= make_date(extract(year from current_date)::int - 4, 1, 1)
  ),
  r as (  -- jump in (adjusted / raw) ratio = stock split (dividends only move it ~1-2%)
    select *, f / nullif(lag(f) over (partition by ticker order by month_end), 0) as fr from base
  ),
  s as (
    select *, case when fr > 1.2 or fr < 0.83 then greatest(round(fr, 1), 0.1) else 1 end as split from r
  ),
  p as (  -- split-adjusted price (dividends NOT added back) for price return
    select ticker, month_end, adj,
           close * exp(sum(ln(split)) over (partition by ticker order by month_end)) as close
    from s
  ),
  q as (  -- last available close of each calendar quarter
    select distinct on (ticker, yq) ticker, yq, y, qn, month_end, close, adj
    from (select p.*, extract(year from month_end)::int as y, extract(quarter from month_end)::int as qn,
                 extract(year from month_end)::int * 4 + extract(quarter from month_end)::int as yq
          from p) s
    order by ticker, yq, month_end desc
  ),
  qr as (
    select ticker, y || 'Q' || qn as period,
           round((close / lag(close) over w - 1) * 100, 2) as ret,
           round((adj / lag(adj) over w - 1) * 100, 2) as tret,
           (current_date <= (make_date(y, qn * 3, 1) + interval '1 month - 1 day')::date) as to_date,
           month_end, yq - lag(yq) over w as gap
    from q window w as (partition by ticker order by yq)
  ),
  yy as (  -- last available close of each calendar year
    select distinct on (ticker, y) ticker, y, month_end, close, adj
    from (select p.*, extract(year from month_end)::int as y from p) s
    order by ticker, y, month_end desc
  ),
  yr as (
    select ticker,
           case when current_date <= make_date(y, 12, 31) then y || 'YTD' else y::text end as period,
           round((close / lag(close) over w - 1) * 100, 2) as ret,
           round((adj / lag(adj) over w - 1) * 100, 2) as tret,
           (current_date <= make_date(y, 12, 31)) as to_date,
           month_end, y - lag(y) over w as gap
    from yy window w as (partition by ticker order by y)
  ),
  allr as (
    select ticker, period, ret, tret, to_date, month_end from qr where gap = 1 and ret is not null
    union all
    select ticker, period, ret, tret, to_date, month_end from yr where gap = 1 and ret is not null
  )
  insert into perf_returns (ticker, period, return_pct, total_return_pct, to_date, price_as_of, updated_at)
  select ticker, period, ret, tret, to_date, month_end, now() from allr
  on conflict (ticker, period) do update set
    return_pct = excluded.return_pct, total_return_pct = excluded.total_return_pct,
    to_date = excluded.to_date, price_as_of = excluded.price_as_of, updated_at = now();
  get diagnostics n = row_count;
  return n;
end;
$$;

-- Pricing coverage for the returns agent
create or replace function get_price_status()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with latest as (select etf, max(as_of) as as_of from etf_constituents group by etf),
  t as (
    select distinct c.ticker from etf_constituents c
    join latest l on l.etf = c.etf and l.as_of = c.as_of
    where c.is_equity and c.ticker is not null
  )
  select jsonb_build_object(
    'tickersInLists', (select count(*) from t),
    'pricedOk', (select count(*) from t join price_fetch_log g using (ticker) where g.last_success is not null),
    'neverPriced', (select count(*) from t left join price_fetch_log g using (ticker) where g.last_success is null),
    'errors', coalesce((select jsonb_agg(jsonb_build_object('ticker', g.ticker, 'avSymbol', g.av_symbol, 'message', g.message))
                        from t join price_fetch_log g using (ticker) where g.status = 'error'), '[]'::jsonb),
    'latestPriceDate', (select max(month_end) from price_monthly),
    'note', 'Prices come from Alpha Vantage (free key, 25 requests/day). A monthly task prices ~24 companies per day on days 2-7 of each month.'
  );
$$;

-- Full table for one ETF: every holding with all its period returns
create or replace function get_returns_table(p_etf text)
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
    where c.etf = upper(trim(p_etf))
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'company', c.company, 'ticker', c.ticker, 'weightPct', c.weight_pct, 'isEquity', c.is_equity,
           'returns', (select coalesce(jsonb_object_agg(r.period, r.return_pct order by r.period), '{}'::jsonb)
                       from perf_returns r
                       where r.ticker = c.ticker
                         and r.period >= (extract(year from current_date)::int - 2)::text))
         order by c.weight_pct desc nulls last), '[]'::jsonb)
  from c;
$$;

revoke execute on function get_tickers_to_fetch(int)        from public, anon, authenticated;
revoke execute on function save_monthly_prices(jsonb)       from public, anon, authenticated;
revoke execute on function refresh_returns_from_prices()    from public, anon, authenticated;
revoke execute on function get_price_status()               from public, anon, authenticated;
revoke execute on function get_returns_table(text)          from public, anon, authenticated;
