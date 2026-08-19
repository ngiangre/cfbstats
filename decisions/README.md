# Decision log

A durable record of substantive decisions, the hypotheses behind them, and —
crucially — **what actually worked and what didn't** as the project evolves.
The goal is for the repo to accumulate knowledge over time so we don't relitigate
settled questions or forget why something was tried and abandoned.

This is the "decision & learning harness" from [VISION.md](../VISION.md) (§9).

## How it works

- One Markdown file per decision, numbered and dated:
  `NNNN-short-slug.md` (e.g., `0002-player-linkage-key.md`).
- Copy [`TEMPLATE.md`](TEMPLATE.md) to start a new entry; take the next number.
- Entries are **append-mostly**: don't rewrite history. To change a past
  decision, add a new entry and mark the old one `Superseded by NNNN`.
- Revisit the **Outcome / what we learned** section later — that is where the
  "what worked" knowledge lives. An entry isn't "done" when the decision is
  made; it's living until the outcome is known.

## Statuses

- `Proposed` — under consideration.
- `Accepted` — decided and in effect.
- `Superseded by NNNN` — replaced by a later decision.
- `Abandoned` — tried, didn't work out (say why in Outcome).

## Relationship to git

Spike/experiment branches (see VISION.md §11) are never merged; their findings
should be **distilled into a decision entry** so the knowledge survives the
branch being deleted.
