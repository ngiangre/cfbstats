# Refresh raw CFBD data into data/*.parquet using the package ingest functions.
# Run locally or by the scheduled data-refresh GitHub Action. Requires
# CFBD_API_KEY. The conference-tier lookup is package-maintained separately
# (see data-raw/conference_tiers.R).

pkgload::load_all(".", quiet = TRUE)

years <- 2010:2026
dir.create("data", showWarnings = FALSE)

arrow::write_parquet(ingest_picks(), "data/picks.parquet")
arrow::write_parquet(ingest_player_stats(years), "data/player_stats.parquet")
arrow::write_parquet(ingest_coaches(), "data/coaches.parquet")
arrow::write_parquet(ingest_teams(), "data/teams.parquet")
arrow::write_parquet(ingest_roster(years), "data/roster.parquet")
arrow::write_parquet(ingest_recruiting(years), "data/recruiting.parquet")

# NFL outcomes via nflverse (decision 0014) — no API key required.
arrow::write_parquet(
  ingest_nfl_draft_picks(years),
  "data/nfl_draft_picks.parquet"
)
arrow::write_parquet(ingest_nfl_rosters(years), "data/nfl_rosters.parquet")
arrow::write_parquet(
  ingest_nfl_player_stats(years),
  "data/nfl_player_stats.parquet"
)

cli::cli_alert_success(
  "Refreshed CFBD data into data/ for {min(years)}-{max(years)}."
)

# The queryable DuckDB bundle (data/cfbstats.duckdb) is built by the pipeline
# from the cleaned tables, not here: run `targets::tar_make(duckdb_file)` after
# a refresh (the data-refresh workflow does this before publishing). Decision 0016.
