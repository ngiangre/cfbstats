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
  # ---- ingest: track committed raw files, then read them --------------------
  tar_target(picks_file, "data/picks.parquet", format = "file"),
  tar_target(player_stats_file, "data/player_stats.parquet", format = "file"),
  tar_target(coaches_file, "data/coaches.parquet", format = "file"),
  tar_target(teams_file, "data/teams.parquet", format = "file"),
  tar_target(tiers_file, "data/conference_tiers.parquet", format = "file"),
  tar_target(roster_file, "data/roster.parquet", format = "file"),
  tar_target(recruiting_file, "data/recruiting.parquet", format = "file"),
  tar_target(raw_picks, arrow::read_parquet(picks_file)),
  tar_target(raw_player_stats, arrow::read_parquet(player_stats_file)),
  tar_target(raw_coaches, arrow::read_parquet(coaches_file)),
  tar_target(raw_teams, arrow::read_parquet(teams_file)),
  tar_target(tiers, arrow::read_parquet(tiers_file)),
  tar_target(raw_roster, arrow::read_parquet(roster_file)),
  tar_target(raw_recruiting, arrow::read_parquet(recruiting_file)),

  # ---- clean ----------------------------------------------------------------
  tar_target(picks, clean_picks(raw_picks)),
  tar_target(player_stats, clean_player_stats(raw_player_stats)),
  tar_target(coaches, clean_coaches(raw_coaches)),
  tar_target(teams, clean_teams(raw_teams)),
  tar_target(roster, clean_roster(raw_roster)),
  tar_target(recruiting, clean_recruiting(raw_recruiting)),

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

  # ---- link -----------------------------------------------------------------
  tar_target(player_season, build_player_season(player_stats)),
  tar_target(ps_coach, link_coaches(player_season, coaches)),
  tar_target(ps_tier, link_tiers(ps_coach, tiers)),
  tar_target(ps_draft, link_drafted(ps_tier, picks)),
  # HS recruiting ratings, name-guarded (decision 0013); kept off the model path.
  tar_target(ps_recruit, link_recruiting(player_season, recruiting)),

  # ---- features -------------------------------------------------------------
  tar_target(ps_change, add_change_features(ps_draft)),
  tar_target(model_table, add_roster_weight(ps_change, roster)),

  # ---- model + report (placeholders) ----------------------------------------
  tar_target(model_fit, fit_draft_model(model_table)),

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
      )
    )
  )
)
