# ETF Agent Report: 3-minute script (slides + demo)

**Total: about 2:46** (14 s of margin within 3:00). About 390 spoken words at ElevenLabs' natural pace (~150 words per minute).
Each block shows the time window, what is on screen, and the narration to paste into ElevenLabs.
`<break time="0.5s" />` tags are ElevenLabs pause tags. Paste them as they are.

**Slides (8, one per block):** 1 Title · 2 The problem · 3 Goal and scope · 4 The solution (animation) · 5 Built on Fidelity × n8n · 6 Demo (switch to the live demo here) · 7 Innovation and impact · 8 Thank you.

---

## 0:00 – 0:12 · Title slide (12 s · ~35 words)

**On screen:** title slide.

> Hi, we're Linh Dan Ngo, Evan Lin, Dylan Li and Luis Mario. <break time="0.3s" /> This is ETF Agent Report: a monthly report that explains what is driving a Fidelity ETF, holding by holding.

---

## 0:12 – 0:30 · The problem (18 s · ~45 words)

**On screen:** "The problem" (Fidelity holdings screenshot + what is missing).

> Fidelity's Investly app helps people invest in ETFs. <break time="0.3s" /> But once the money is in, most clients stop paying attention. The fund page shows only names and weights. <break time="0.3s" /> Research shows that investors who understand why their investments moved stay more loyal, while those who trade more earn less.

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

## 1:15 – 2:06 · DEMO (51 s · ~130 words)

**On screen:** slide 6 "Demo" shows only the dashboard link. Click it, do the demo, and come back to the presentation for slide 7.

Before you start, have **n8n** (the project's workflow list) open in a browser tab. The link on slide 6 opens the dashboard.

| Time | Action on screen | Narration |
|---|---|---|
| 1:15 – 1:17 | **Slide 6:** click the "Live demo" link (opens the dashboard) | > Let's see it live. |
| 1:17 – 1:27 | **Dashboard** on FCCL: point at the KPI cards and top contributors | > This is what you'd get every month. For FCCL you see the holdings, how much is priced, and who contributed most this year. |
| 1:27 – 1:37 | Scroll to **Fund map**. Hover RY, then TD | > The fund map shows every holding: box size is its weight, colour is its return. Green is up, grey means no price yet. |
| 1:37 – 1:47 | Click the **TD** box (the table filters), point at the YTD and Contrib. columns | > Click Toronto-Dominion Bank: up thirty-six percent this year with a four point six percent weight. That's one point six seven points for the fund. |
| 1:47 – 1:51 | Clear the search, click the **FCCM** tab | > And the same view works for every ETF. |
| 1:51 – 2:06 | Switch to the **n8n** tab: hover the 4 workflows, open "Prices – monthly Alpha Vantage fetch" for 3 s, then go back to the presentation (slide 7) | > Behind it, n8n runs four workflows: holdings on day one, prices on days two to seven, and two AI agents. All on a schedule, with no manual steps. |

Narration for ElevenLabs, as one block:

> Let's see it live. <break time="0.5s" />
> This is what you'd get every month. For FCCL you see the holdings, how much is priced, and who contributed most this year. <break time="0.5s" />
> The fund map shows every holding: box size is its weight, colour is its return. Green is up, grey means no price yet. <break time="0.5s" />
> Click Toronto-Dominion Bank: up thirty-six percent this year with a four point six percent weight. That's one point six seven points for the fund. <break time="0.5s" />
> And the same view works for every ETF. <break time="0.5s" />
> Behind it, n8n runs four workflows: holdings on day one, prices on days two to seven, and two AI agents. All on a schedule, with no manual steps.

---

## 2:06 – 2:36 · Innovation and impact (30 s · ~75 words)

**On screen:** "Innovation and impact".

> For the investor, it's a reason to come back every month and understand their money, with no trades and nothing at risk. <break time="0.3s" /> For Fidelity and Investly, the research points the same way. Finimize found that seventy-four percent of its customers would invest more with more chances to learn. <break time="0.3s" /> And for one asset manager studied by S S and C, twenty-one percent higher retention meant thirty-three percent more revenue. <break time="0.3s" /> All of it runs automatically, on data Fidelity already has.

---

## 2:36 – 2:46 · Thank you (10 s · ~25 words)

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
