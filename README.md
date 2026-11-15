# ETF Agent Report

**A monthly report that shows what is driving a Fidelity ETF, holding by holding.**

**Live dashboard:** <https://chimerical-arithmetic-142fdb.netlify.app>  
**Slides:** <https://itsluismario.github.io/ETF-agent-report/presentation/presentation-preview.html>  
**Demo video:** <https://youtu.be/ajhhFmpHxX8>

## The problem

Fidelity's ETF pages for **FCCA** and its four underlying ETFs (**FCCL, FCCV, FCCQ, FCCM**) list each fund's holdings and the percentage weight of each company. **That's all they show.** They don't say how each company has performed or what has been happening with it.

An investor can see *what* they own and *how much*, but not *how each holding is doing*. To find out, they have to look up each company by hand: more than 100 companies across the four ETFs.

The fund page answers **"What's in my ETF?"** but not **"Which of these companies are helping or hurting my returns, and why?"**

## How this report helps

The report pairs each holding's **weight** with its **performance**, so the investor can see which companies drive the fund's results and monitor them month by month, without researching 100+ companies by hand.

| Feature | What it gives the investor | Status |
|---|---|---|
| **Performance by quarter and by year** | % return of every company for each quarter (Q1–Q4) and each year (plus YTD), next to its weight in the ETF, and its **contribution** to the fund (weight × return). Top and lowest contributors per ETF. | ✅ Live |
| **News and sentiment per company** | Most relevant news of the past month per company, each item and the month rated *Very good / Good / Bad / Very bad*, with a short summary and source link. | 🔜 Next step |

**Scope:** FCCL, FCCV, FCCQ and FCCM (the four ETFs inside FCCA) · **Frequency:** monthly · **Delivery:** live web dashboard · **Price data:** Alpha Vantage · **Holdings data:** Fidelity Canada product data.

## How it works

```
Fidelity product data ──► n8n: Holdings refresh (day 1)  ──► Supabase: etf_constituents
Alpha Vantage prices  ──► n8n: Price collection (days 2–7) ──► Supabase: price_monthly → perf_returns
                          n8n: Returns Agent               ──► Supabase: report_runs (summary)
Netlify (site/index.html) ──► Supabase get_public_report() (read-only, live on every visit)
```

| Workflow (n8n) | Type | Role |
|---|---|---|
| Holdings – monthly refresh | Scheduled, day 1 | Downloads the full holdings list of each ETF (company, weight, as-of date); reuses known tickers |
| ETF Holdings Agent | AI agent (Gemini Flash-Lite) | Maps company names to TSX tickers; new ones are marked "unverified until priced" |
| Prices – monthly Alpha Vantage fetch | Scheduled, days 2–7 | Month-end prices for ~24 companies a day (free key: 25/day); returns computed in SQL, adjusted for stock splits |
| ETF Returns Agent | AI agent (Gemini Flash-Lite) | Writes a short summary of top / lowest contributors for the dashboard |

## Data sources

| Data | Service / API | Endpoint | Cost & limits |
|---|---|---|---|
| ETF holdings (company, weight %, market value, as-of date) | **Fidelity Canada product API** (the data behind the "View all" holdings on fidelity.ca) | `GET https://fidcaproductsapi.fidelity.ca/FidcaProductsAPI/api/fundPage/fund/EN/{ETF}` → `holdingsByCategory` | Free, no key. Called once a month per ETF |
| Stock prices (month-end close and adjusted close) | **[Alpha Vantage](https://www.alphavantage.co/)** | `GET https://www.alphavantage.co/query?function=TIME_SERIES_MONTHLY_ADJUSTED&symbol={TICKER}.TRT&apikey=…` | Free key: 25 requests/day, 5/minute. TSX tickers use the `.TRT` suffix; class shares use a dash (`CTC-A.TRT`). Prices are kept in the currency the API returns (CAD for TSX listings) |
| Company name → ticker mapping | **Google Gemini** (`gemini-3.5-flash-lite`, free tier) via the n8n AI Agent | Gemini API | Free tier. Tickers are marked "unverified" until Alpha Vantage returns a price for them |
| Storage and the public data endpoint | **[Supabase](https://supabase.com/)** (Postgres + PostgREST) | `POST /rest/v1/rpc/get_public_report` | Free tier |
| Website hosting | **[Netlify](https://www.netlify.com/)** | — | Free tier |

Returns (quarterly, annual, YTD) and contributions (weight × return) are not fetched from any service. They are calculated in SQL from the monthly prices.

## Engineering highlights

- **Performance Fidelity doesn't show**: Fidelity lists every holding and its weight; we add each company's quarterly, annual and YTD returns, computed in SQL from monthly prices.
- **Works within free limits**: a price queue respects Alpha Vantage's 25 requests/day, and the agents use 2 model requests per run.
- **Correct returns**: stock splits are detected from adjusted vs. raw prices (Loblaw showed −67% before the fix and +31.20% after it).
- **Honest data**: missing values are shown as *n/a*, never estimated.
- **Secure public page**: Row Level Security on every table; the publishable key can call one read-only function only.

## Repository

| Path | Contents |
|---|---|
| `site/index.html` | The dashboard (single file, no build step) |
| `supabase/01…04_*.sql` | Database schema and functions, run in order |
| `presentation/presentation.qmd` | Quarto reveal.js slides (`quarto render presentation/presentation.qmd`) |
| `presentation/presentation-preview.html` | Pre-rendered preview of the slides (open in a browser) |
| `netlify.toml` | Publishes the `site/` folder |

## Setup from scratch

1. **Supabase**: in *SQL Editor*, run the files in `supabase/` in order (01 → 04). They are safe to run more than once.
2. **n8n**: create credentials (Postgres → Supabase *Session pooler*, Google Gemini, Alpha Vantage as *Query Auth* with `apikey`) and rebuild the four workflows above.
3. **Netlify**: link this repository. `netlify.toml` publishes `site/`; there is no build command.
4. In `site/index.html`, set `SUPABASE_URL` and `SUPABASE_ANON_KEY` to your project URL and **publishable** key.

## Limitations

- News and sentiment (Feature 1) is not built yet.
- The combined FCCA view is planned; today the report covers its four underlying ETFs.
- Prices fill in on days 2–7 of each month because of the free API limit; a few symbols are not available from the source (e.g. Dollarama, Canadian Pacific).
- Contribution uses today's weights for past periods: an approximation, not the fund's official return.

## Security

The page uses Supabase's **publishable** key, which is meant to be public. Never commit the Supabase *secret* / `service_role` key, database passwords or API keys (Alpha Vantage, Gemini). Those live only in n8n credentials.

*Information only, not investment advice.*
