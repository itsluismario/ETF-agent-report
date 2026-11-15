-- 05 · ETF overlap / similarity functions used by the Returns Agent tools
--        find_similar_etfs → get_similar_etfs(etf, limit)
--        get_etf_overlap   → get_etf_overlap(etfA, etfB)
-- Overlap is measured on each ETF's latest holdings list (equities only),
-- matching companies by ticker (or by name when there is no ticker).
-- Overlap weight = sum over shared companies of min(weight in A, weight in B).
-- Safe to run more than once.

create or replace function public.get_etf_overlap(p_a text, p_b text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with latest as (
    select etf, max(as_of) as as_of from etf_constituents group by etf
  ),
  h as (
    select c.etf,
           coalesce(nullif(c.ticker, ''), upper(c.company)) as k,
           max(c.company) as company,
           max(c.ticker)  as ticker,
           sum(c.weight_pct)::numeric as w
    from etf_constituents c
    join latest l on l.etf = c.etf and l.as_of = c.as_of
    where c.is_equity
    group by c.etf, 2
  ),
  a as (select * from h where etf = upper(trim(p_a))),
  b as (select * from h where etf = upper(trim(p_b)))
  select jsonb_build_object(
    'etfA', upper(trim(p_a)),
    'etfB', upper(trim(p_b)),
    'holdingsA', (select count(*) from a),
    'holdingsB', (select count(*) from b),
    'sharedCount', (select count(*) from a join b on a.k = b.k),
    'overlapWeightPct', round(coalesce((select sum(least(a.w, b.w)) from a join b on a.k = b.k), 0), 2),
    'shared', coalesce((
      select jsonb_agg(jsonb_build_object(
               'company', a.company, 'ticker', a.ticker,
               'weightA', round(a.w, 2), 'weightB', round(b.w, 2))
             order by least(a.w, b.w) desc)
      from a join b on a.k = b.k), '[]'::jsonb),
    'onlyInA', coalesce((
      select jsonb_agg(jsonb_build_object('company', x.company, 'ticker', x.ticker, 'weight', round(x.w, 2)) order by x.w desc)
      from (select * from a where a.k not in (select k from b) order by w desc limit 15) x), '[]'::jsonb),
    'onlyInB', coalesce((
      select jsonb_agg(jsonb_build_object('company', x.company, 'ticker', x.ticker, 'weight', round(x.w, 2)) order by x.w desc)
      from (select * from b where b.k not in (select k from a) order by w desc limit 15) x), '[]'::jsonb),
    'note', 'Top 15 shown for onlyInA / onlyInB. Overlap = sum of min(weight A, weight B) over shared companies.'
  );
$$;

create or replace function public.get_similar_etfs(p_etf text, p_limit int default 5)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with latest as (
    select etf, max(as_of) as as_of from etf_constituents group by etf
  ),
  h as (
    select c.etf,
           coalesce(nullif(c.ticker, ''), upper(c.company)) as k,
           sum(c.weight_pct)::numeric as w
    from etf_constituents c
    join latest l on l.etf = c.etf and l.as_of = c.as_of
    where c.is_equity
    group by c.etf, 2
  ),
  base as (select * from h where etf = upper(trim(p_etf))),
  scores as (
    select o.etf,
           count(*) as shared_count,
           round(sum(least(b.w, o.w)), 2) as overlap
    from h o join base b on b.k = o.k
    where o.etf <> upper(trim(p_etf))
    group by o.etf
  )
  select jsonb_build_object(
    'etf', upper(trim(p_etf)),
    'comparedAgainst', (select count(distinct etf) - 1 from h),
    'similar', coalesce((
      select jsonb_agg(jsonb_build_object('etf', s.etf, 'overlapWeightPct', s.overlap, 'sharedCount', s.shared_count)
                       order by s.overlap desc)
      from (select * from scores order by overlap desc limit greatest(coalesce(p_limit, 5), 1)) s), '[]'::jsonb),
    'note', 'Only ETFs whose holdings are stored in this database are compared (currently FCCL, FCCV, FCCQ, FCCM).'
  );
$$;

revoke all on function public.get_etf_overlap(text, text) from public, anon, authenticated;
revoke all on function public.get_similar_etfs(text, int) from public, anon, authenticated;
