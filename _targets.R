# cfbstats pipeline (decision 0004). Single source of truth for the processing
# graph, lineage/audit (decision 0005), and the rendered process map.
#
# Stages: ingest -> clean -> link -> features -> model -> report.
#
# Ingest targets read the committed raw parquet in data/ so the pipeline runs
# offline. A fresh CFBD pull (the scheduled refresh job) instead calls the
# ingest_*() functions in R/ingest.R.

library(targets)

tar_option_set(
  packages = c("dplyr", "arrow", "tibble", "tidyr", "purrr", "pointblank"),
  format = "rds"
)

# Load all package functions (R/).
targets::tar_source()

list(
  # ---- ingest -> raw parquet assets (decision 0017) -------------------------
  # In refresh mode (CFBSTATS_REFRESH=true) parquet_asset() ingests from
  # CFBD/nflverse and WRITES the raw parquet; otherwise it tracks the existing
  # committed/downloaded file (no API key). `cue = always` so a local re-refresh
  # always re-ingests; in track mode the command just returns the path (cheap)
  # and downstream rebuilds only on an actual file-hash change. The site build
  # runs in track mode.
  tar_target(
    picks_file,
    parquet_asset("data/picks.parquet", ingest_picks),
    format = "file",
    cue = tar_cue(mode = "always")
  ),
  tar_target(
    player_stats_file,
    parquet_asset("data/player_stats.parquet", ingest_player_stats),
    format = "file",
    cue = tar_cue(mode = "always")
  ),
  tar_target(
    coaches_file,
    parquet_asset("data/coaches.parquet", ingest_coaches),
    format = "file",
    cue = tar_cue(mode = "always")
  ),
  tar_target(
    teams_file,
    parquet_asset("data/teams.parquet", ingest_teams),
    format = "file",
    cue = tar_cue(mode = "always")
  ),
  tar_target(
    roster_file,
    parquet_asset("data/roster.parquet", ingest_roster),
    format = "file",
    cue = tar_cue(mode = "always")
  ),
  tar_target(
    recruiting_file,
    parquet_asset("data/recruiting.parquet", ingest_recruiting),
    format = "file",
    cue = tar_cue(mode = "always")
  ),
  # NFL outcomes via nflverse (decision 0014); no CFBD key required to ingest.
  tar_target(
    nfl_draft_picks_file,
    parquet_asset("data/nfl_draft_picks.parquet", ingest_nfl_draft_picks),
    format = "file",
    cue = tar_cue(mode = "always")
  ),
  tar_target(
    nfl_rosters_file,
    parquet_asset("data/nfl_rosters.parquet", ingest_nfl_rosters),
    format = "file",
    cue = tar_cue(mode = "always")
  ),
  tar_target(
    nfl_player_stats_file,
    parquet_asset("data/nfl_player_stats.parquet", ingest_nfl_player_stats),
    format = "file",
    cue = tar_cue(mode = "always")
  ),
  tar_target(raw_picks, arrow::read_parquet(picks_file)),
  tar_target(raw_player_stats, arrow::read_parquet(player_stats_file)),
  tar_target(raw_coaches, arrow::read_parquet(coaches_file)),
  tar_target(raw_teams, arrow::read_parquet(teams_file)),
  tar_target(raw_roster, arrow::read_parquet(roster_file)),
  tar_target(raw_recruiting, arrow::read_parquet(recruiting_file)),
  tar_target(raw_nfl_draft_picks, arrow::read_parquet(nfl_draft_picks_file)),
  tar_target(raw_nfl_rosters, arrow::read_parquet(nfl_rosters_file)),
  tar_target(raw_nfl_player_stats, arrow::read_parquet(nfl_player_stats_file)),
  # conference_tiers is derived in-pipeline from the ingested player_stats
  # (decision 0017): its own parquet asset in refresh mode, else tracked.
  tar_target(
    tiers_file,
    parquet_asset(
      "data/conference_tiers.parquet",
      function() build_conference_tiers(raw_player_stats)
    ),
    format = "file",
    cue = tar_cue(mode = "always")
  ),
  tar_target(tiers, arrow::read_parquet(tiers_file)),

  # ---- clean ----------------------------------------------------------------
  tar_target(picks, clean_picks(raw_picks)),
  tar_target(player_stats, clean_player_stats(raw_player_stats)),
  tar_target(coaches, clean_coaches(raw_coaches)),
  tar_target(teams, clean_teams(raw_teams)),
  tar_target(roster, clean_roster(raw_roster)),
  tar_target(recruiting, clean_recruiting(raw_recruiting)),
  tar_target(nfl_draft_picks, clean_nfl_draft_picks(raw_nfl_draft_picks)),
  tar_target(nfl_rosters, clean_nfl_rosters(raw_nfl_rosters)),
  tar_target(nfl_player_stats, clean_nfl_player_stats(raw_nfl_player_stats)),

  # ---- contracts (decision 0005): pass/fail feeds the audit log -------------
  tar_target(
    ok_picks,
    pointblank::all_passed(
      contract_picks(picks, stop_on_fail = FALSE)
    )
  ),
  tar_target(
    ok_player_stats,
    pointblank::all_passed(
      contract_player_stats(player_stats, stop_on_fail = FALSE)
    )
  ),
  tar_target(
    ok_coaches,
    pointblank::all_passed(
      contract_coaches(coaches, stop_on_fail = FALSE)
    )
  ),
  tar_target(
    ok_roster,
    pointblank::all_passed(
      contract_roster(roster, stop_on_fail = FALSE)
    )
  ),
  tar_target(
    ok_recruiting,
    pointblank::all_passed(
      contract_recruiting(recruiting, stop_on_fail = FALSE)
    )
  ),
  tar_target(
    ok_teams,
    pointblank::all_passed(
      contract_teams(teams, player_season, stop_on_fail = FALSE)$coverage
    )
  ),
  tar_target(
    ok_tiers,
    pointblank::all_passed(
      contract_conference_tiers(
        tiers,
        player_stats,
        stop_on_fail = FALSE
      )$coverage
    )
  ),
  tar_target(
    ok_drafted,
    pointblank::all_passed(
      contract_drafted(ps_draft, ps_tier, stop_on_fail = FALSE)
    )
  ),
  tar_target(
    ok_nfl_draft_picks,
    pointblank::all_passed(
      contract_nfl_draft_picks(nfl_draft_picks, stop_on_fail = FALSE)
    )
  ),
  tar_target(
    ok_nfl_rosters,
    pointblank::all_passed(
      contract_nfl_rosters(nfl_rosters, stop_on_fail = FALSE)
    )
  ),
  tar_target(
    ok_nfl_player_stats,
    pointblank::all_passed(
      contract_nfl_player_stats(nfl_player_stats, stop_on_fail = FALSE)
    )
  ),
  tar_target(
    ok_nfl_link,
    pointblank::all_passed(
      contract_nfl_link(picks_nfl, picks, stop_on_fail = FALSE)
    )
  ),

  # ---- link -----------------------------------------------------------------
  tar_target(player_season, build_player_season(player_stats)),
  tar_target(ps_coach, link_coaches(player_season, coaches)),
  tar_target(ps_tier, link_tiers(ps_coach, tiers)),
  tar_target(ps_draft, link_drafted(ps_tier, picks)),
  # HS recruiting ratings, name-guarded (decision 0013); kept off the model path.
  tar_target(ps_recruit, link_recruiting(player_season, recruiting)),
  # NFL outcomes bridged to CFBD picks by draft slot (decision 0014); an
  # outcome/label source, kept off the model input path.
  tar_target(picks_nfl, link_nfl_draft(picks, nfl_draft_picks)),

  # ---- features -------------------------------------------------------------
  tar_target(ps_change, add_change_features(ps_draft)),
  tar_target(model_table, add_roster_weight(ps_change, roster)),

  # ---- model + report (placeholders) ----------------------------------------
  tar_target(model_fit, fit_draft_model(model_table)),

  # ---- package: bundle cleaned tables into a queryable DuckDB asset ----------
  # One SQL-queryable file carrying the cleaned, contract-checked tables (the
  # schemas in inst/dict/*.yml), published alongside the parquet on the
  # data-latest release (decision 0016). format = "file" so targets tracks it.
  tar_target(
    duckdb_file,
    build_duckdb(
      list(
        picks = picks,
        player_stats = player_stats,
        coaches = coaches,
        teams = teams,
        conference_tiers = tiers,
        roster = roster,
        recruiting = recruiting,
        nfl_draft_picks = nfl_draft_picks,
        nfl_rosters = nfl_rosters,
        nfl_player_stats = nfl_player_stats
      ),
      "data/cfbstats.duckdb"
    ),
    format = "file"
  ),

  # ---- audit log (decision 0005): one uniform row per tracked step ----------
  tar_target(
    audit_log,
    dplyr::bind_rows(
      audit_step(
        picks,
        "clean_picks",
        "clean",
        raw_picks,
        keys = "playerId",
        contract_passed = ok_picks
      ),
      audit_step(
        player_stats,
        "clean_player_stats",
        "clean",
        raw_player_stats,
        keys = c("playerId", "season"),
        contract_passed = ok_player_stats
      ),
      audit_step(
        coaches,
        "clean_coaches",
        "clean",
        raw_coaches,
        keys = c("coach_id", "season"),
        contract_passed = ok_coaches
      ),
      audit_step(
        roster,
        "clean_roster",
        "clean",
        raw_roster,
        keys = c("playerId", "season"),
        contract_passed = ok_roster
      ),
      audit_step(
        recruiting,
        "clean_recruiting",
        "clean",
        raw_recruiting,
        keys = "playerId",
        contract_passed = ok_recruiting
      ),
      audit_step(
        teams,
        "clean_teams",
        "clean",
        raw_teams,
        keys = "team",
        contract_passed = ok_teams
      ),
      audit_step(
        player_season,
        "build_player_season",
        "link",
        player_stats,
        keys = c("playerId", "season")
      ),
      audit_step(
        ps_coach,
        "link_coaches",
        "link",
        player_season,
        keys = c("playerId", "season")
      ),
      audit_step(
        ps_tier,
        "link_tiers",
        "link",
        ps_coach,
        contract_passed = ok_tiers
      ),
      audit_step(
        ps_draft,
        "link_drafted",
        "link",
        ps_tier,
        keys = c("playerId", "season"),
        contract_passed = ok_drafted
      ),
      audit_step(ps_change, "add_change_features", "features", ps_draft),
      audit_step(
        model_table,
        "add_roster_weight",
        "features",
        ps_change,
        keys = c("playerId", "season")
      ),
      audit_step(
        ps_recruit,
        "link_recruiting",
        "link",
        player_season,
        keys = c("playerId", "season")
      ),
      audit_step(
        nfl_draft_picks,
        "clean_nfl_draft_picks",
        "clean",
        raw_nfl_draft_picks,
        keys = c("season", "round", "pick"),
        contract_passed = ok_nfl_draft_picks
      ),
      audit_step(
        nfl_rosters,
        "clean_nfl_rosters",
        "clean",
        raw_nfl_rosters,
        keys = c("gsis_id", "season"),
        contract_passed = ok_nfl_rosters
      ),
      audit_step(
        nfl_player_stats,
        "clean_nfl_player_stats",
        "clean",
        raw_nfl_player_stats,
        keys = c("gsis_id", "season"),
        contract_passed = ok_nfl_player_stats
      ),
      audit_step(
        picks_nfl,
        "link_nfl_draft",
        "link",
        picks,
        keys = "playerId",
        contract_passed = ok_nfl_link
      )
    )
  )
)
