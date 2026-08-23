# Refresh raw CFBD data into data/*.parquet using the package ingest functions.
# Run locally or by the scheduled data-refresh GitHub Action. Requires
# CFBD_API_KEY. The conference-tier lookup is package-maintained separately
# (see data-raw/conference_tiers.R).

pkgload::load_all(".", quiet = TRUE)

years <- 2010:2025
dir.create("data", showWarnings = FALSE)

arrow::write_parquet(ingest_picks(), "data/picks.parquet")
arrow::write_parquet(ingest_player_stats(years), "data/player_stats.parquet")
arrow::write_parquet(ingest_coaches(), "data/coaches.parquet")
arrow::write_parquet(ingest_teams(), "data/teams.parquet")
arrow::write_parquet(ingest_roster(years), "data/roster.parquet")

cli::cli_alert_success(
  "Refreshed CFBD data into data/ for {min(years)}-{max(years)}."
)
