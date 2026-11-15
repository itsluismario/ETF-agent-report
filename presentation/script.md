# ETF Agent Report: 3-minute script (slides + demo)

**Total: about 2:40** (20 s of margin within 3:00). About 370 spoken words at ElevenLabs' natural pace (~150 words per minute).
Each block shows the time window, what is on screen, and the narration to paste into ElevenLabs.
`<break time="0.5s" />` tags are ElevenLabs pause tags. Paste them as they are.

**Slides (8, one per block):** 1 Title · 2 The problem · 3 Goal and scope · 4 The solution (animation) · 5 Built on Fidelity × n8n · 6 Demo (switch to the live demo here) · 7 Innovation and impact · 8 Thank you.

---

## 0:00 – 0:12 · Title slide (12 s · ~35 words)

**On screen:** title slide.

> Hi, we're Linh Dan Ngo, Evan Lin, Dylan Li and Luis Mario. <break time="0.3s" /> This is ETF Agent Report: a monthly report that explains what is driving a Fidelity ETF, holding by holding.

---

## 0:12 – 0:30 · The problem (18 s · ~45 words)

**On screen:** "The problem".

> Fidelity's Investly app helps people invest in ETFs. <break time="0.3s" /> But once the money is in, most clients stop paying attention. The fund page shows only names and weights, and fewer than half of investors know everything they hold. <break time="0.3s" /> And pushing them to trade isn't the answer: the most active traders earn less.

---

## 0:30 – 0:42 · Goal and scope (12 s · ~30 words)

**On screen:** "Goal and scope".

> Our goal: keep ETF investors involved every month, without asking them to trade. <break time="0.3s" /> Each month they get a report on their own ETF: which companies moved it, and by how much.

---

## 0:42 – 1:05 · The solution in one picture (23 s · ~55 words)

**On screen:** the animation. Press **1** when you start speaking so it plays from the beginning (each step lasts 2 s).

> Here's how it flows. <break time="0.3s" /> On day one, n8n downloads the full holdings list from Fidelity, and an AI agent matches every company to its stock ticker. <break time="0.3s" /> On days two to seven, n8n collects month-end prices. Postgres calculates the returns, an agent writes a summary, and the dashboard reads it live.

---

## 1:05 – 1:15 · Built on Fidelity × n8n (10 s · ~25 words)

**On screen:** "Built on Fidelity × n8n".

> Fidelity gives us the data and the question. <break time="0.2s" /> n8n is the engine: four workflows, two AI agents, and a monthly schedule with no manual steps.

---

## 1:15 – 2:15 · DEMO (60 s · ~150 words)

**On screen:** start on slide 6 "Demo", then switch to the browser.

Record the screen while the audio plays, or present live. Have these tabs open in this order before you start:
1. `fidelity.ca/en/products/etfs/fccl/` scrolled to the holdings list
2. n8n → the project's workflow list
3. The dashboard: <https://chimerical-arithmetic-142fdb.netlify.app>

| Time | Action on screen | Narration |
|---|---|---|
| 1:15 – 1:23 | **Tab 1:** Fidelity FCCL page, scroll the holdings | > Imagine you hold FCCL. Today, this is what you see: names and weights, nothing about performance. |
| 1:23 – 1:38 | **Tab 2:** n8n. Hover the 4 workflows, then open "Prices – monthly Alpha Vantage fetch" for 3 s | > In n8n we have four workflows. Holdings refresh on day one, prices on days two to seven, and two AI agents. Everything runs on a schedule. |
| 1:38 – 1:48 | **Tab 3:** dashboard on FCCL, point at the KPI cards and top contributors | > And this is what you'd get every month. For FCCL you see the holdings, how much is priced, and who contributed most this year. |
| 1:48 – 1:58 | Scroll to **Fund map**. Hover RY, then TD | > The fund map shows every holding: box size is its weight, colour is its return. Green is up, grey means no price yet. |
| 1:58 – 2:08 | Click the **TD** box (the table filters), point at the YTD and Contrib. columns | > Click Toronto-Dominion Bank: up thirty-six percent this year with a four point six percent weight. That's one point six seven points for the fund. |
| 2:08 – 2:15 | Clear the search, click the **FCCM** tab | > And the same view works for every ETF. |

Narration for ElevenLabs, as one block (~150 words):

> Imagine you hold FCCL. Today, this is what you see: names and weights, nothing about performance. <break time="0.5s" />
> In n8n we have four workflows. Holdings refresh on day one, prices on days two to seven, and two AI agents. Everything runs on a schedule. <break time="0.5s" />
> And this is what you'd get every month. For FCCL you see the holdings, how much is priced, and who contributed most this year. <break time="0.5s" />
> The fund map shows every holding: box size is its weight, colour is its return. Green is up, grey means no price yet. <break time="0.5s" />
> Click Toronto-Dominion Bank: up thirty-six percent this year with a four point six percent weight. That's one point six seven points for the fund. <break time="0.5s" />
> And the same view works for every ETF.

---

## 2:15 – 2:30 · Innovation and impact (15 s · ~38 words)

**On screen:** "Innovation and impact".

> For the investor, it's a reason to come back every month and understand their money, with no trades and nothing at risk. <break time="0.3s" /> For Fidelity and Investly, engaged investors stay longer and invest more. And it runs automatically, on data Fidelity already has.

---

## 2:30 – 2:40 · Thank you (10 s · ~25 words)

**On screen:** "Thank you".

> Next, we'll add news and sentiment for every company. <break time="0.3s" /> Thank you! The live dashboard and the code are linked here.

---

## ElevenLabs tips

- **Generate one clip per block**, not the whole script at once. If a clip runs long, you only redo that block.
- **Check each clip's length** against the window above. If it runs long, trim words rather than speeding the voice up. Lower Stability (~40–50%) sounds more natural; higher sounds steadier.
- **Numbers are written as words** ("thirty-six percent", "one point six seven") so the voice reads them correctly.
- **Pronunciation:**
  - n8n is said "n-eight-n".
  - FCCA, FCCL, FCCM are spelled letter by letter. If the voice slurs them, write "F-C-C-A".
  - Postgres is said "post-gress".
- **Syncing the animation:** on slide 4 each step lasts 2 s. Press **1** at the first word, and the narration follows steps 1–8 in order.
