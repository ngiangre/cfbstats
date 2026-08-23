# Data contracts (decision 0005 / VISION §8). pointblank agents that assert the
# schema, key integrity, and value ranges we depend on, run as pipeline targets
# so broken assumptions fail fast. contract_conference_tiers() lives in
# conference_tiers.R; these cover the other core datasets. Kept intentionally
# shallow for the skeleton — tighten as features land.

#' Run a contract and optionally abort
#'
#' @param agent An interrogated pointblank agent.
#' @param label Dataset label for the error message.
#' @param stop_on_fail Abort on failure?
#' @return The agent, invisibly.
#' @keywords internal
enforce_contract <- function(agent, label, stop_on_fail) {
  if (stop_on_fail && !pointblank::all_passed(agent)) {
    cli::cli_abort("The {.val {label}} data contract failed.")
  }
  invisible(agent)
}

#' Data contract for cleaned picks
#'
#' @param picks Cleaned picks (see [clean_picks()]).
#' @param stop_on_fail Abort on failure (default `TRUE`)?
#' @return The interrogated pointblank agent, invisibly.
#' @export
contract_picks <- function(picks, stop_on_fail = TRUE) {
  rlang::check_installed("pointblank")
  # Raw picks carry the full NFL draft history (back to 1936), not just our
  # 2010-2025 stats window; bound the year check accordingly.
  agent <- pointblank::create_agent(picks, label = "picks") |>
    pointblank::col_exists(c("collegeAthleteId", "year", "round", "overall")) |>
    # Columns documented in inst/dict/picks.yml that clean_picks passes through.
    pointblank::col_exists(c(
      "nflAthleteId",
      "collegeId",
      "collegeConference",
      "nflTeamId",
      "nflTeam",
      "pick",
      "name",
      "preDraftPositionRanking",
      "preDraftGrade",
      "hometownInfo_city",
      "hometownInfo_country",
      "hometownInfo_latitude",
      "hometownInfo_longitude",
      "hometownInfo_countyFips"
    )) |>
    pointblank::col_vals_between("year", 1936, 2026) |>
    pointblank::col_vals_between("round", 1, 30, na_pass = TRUE) |>
    pointblank::interrogate()
  enforce_contract(agent, "picks", stop_on_fail)
}

#' Data contract for cleaned long player stats
#'
#' @param player_stats Cleaned long stats (see [clean_player_stats()]).
#' @param stop_on_fail Abort on failure (default `TRUE`)?
#' @return The interrogated pointblank agent, invisibly.
#' @export
contract_player_stats <- function(player_stats, stop_on_fail = TRUE) {
  rlang::check_installed("pointblank")
  agent <- pointblank::create_agent(player_stats, label = "player_stats") |>
    pointblank::col_exists(c(
      "season",
      "playerId",
      "team",
      "conference",
      "category",
      "statType",
      "stat"
    )) |>
    pointblank::col_vals_not_null(pointblank::vars(playerId, season)) |>
    pointblank::col_vals_between("season", 2010, 2025) |>
    pointblank::interrogate()
  enforce_contract(agent, "player_stats", stop_on_fail)
}

#' Data contract for cleaned coaches
#'
#' @param coaches Cleaned coaches (see [clean_coaches()]).
#' @param stop_on_fail Abort on failure (default `TRUE`)?
#' @return The interrogated pointblank agent, invisibly.
#' @export
contract_coaches <- function(coaches, stop_on_fail = TRUE) {
  rlang::check_installed("pointblank")
  agent <- pointblank::create_agent(coaches, label = "coaches") |>
    pointblank::col_exists(c("coach_id", "school", "season", "srs", "wins")) |>
    pointblank::col_vals_not_null(pointblank::vars(coach_id, school, season)) |>
    pointblank::col_vals_between("season", 1869, 2026) |>
    pointblank::interrogate()
  enforce_contract(agent, "coaches", stop_on_fail)
}

#' Data contract for the team dimension
#'
#' Validates the cleaned team dimension and, crucially, its *coverage*: every
#' `team` present in the player-season backbone must resolve to a row so a
#' logo/color join never silently drops a program. Logo *presence* is not a hard
#' check — a few small programs legitimately carry no logo URL (a placeholder is
#' used at display time), so that is left to a softer signal.
#'
#' @param teams Cleaned team dimension (see [clean_teams()]).
#' @param player_season Player-season backbone (see [build_player_season()]); the
#'   coverage universe the dimension must fully cover.
#' @param stop_on_fail If `TRUE` (default), raise an error when any check fails.
#'
#' @return Invisibly, a list of the two interrogated `pointblank` agents
#'   (`dim`, `coverage`).
#' @export
contract_teams <- function(teams, player_season, stop_on_fail = TRUE) {
  rlang::check_installed("pointblank")
  teams <- dplyr::collect(teams)
  player_season <- dplyr::collect(player_season)

  agent_dim <-
    pointblank::create_agent(teams, label = "teams: dimension") |>
    pointblank::col_exists(c(
      "team",
      "logo_light",
      "logo_dark",
      "conference"
    )) |>
    pointblank::col_vals_not_null(pointblank::vars(team)) |>
    pointblank::rows_distinct(pointblank::vars(team)) |>
    pointblank::interrogate()

  # Referential coverage: every player_season team has a dimension row.
  coverage <- player_season |>
    dplyr::distinct(.data$team) |>
    dplyr::filter(!is.na(.data$team)) |>
    dplyr::left_join(
      dplyr::transmute(teams, team = .data$team, has_row = TRUE),
      by = "team"
    ) |>
    dplyr::mutate(has_row = !is.na(.data$has_row))

  agent_coverage <-
    pointblank::create_agent(coverage, label = "teams: coverage") |>
    pointblank::col_vals_equal("has_row", TRUE) |>
    pointblank::interrogate()

  if (stop_on_fail) {
    if (!pointblank::all_passed(agent_dim)) {
      cli::cli_abort("The {.file teams} dimension failed its data contract.")
    }
    if (!pointblank::all_passed(agent_coverage)) {
      missing <- dplyr::filter(coverage, !.data$has_row)
      cli::cli_abort(c(
        "The {.file teams} dimension does not cover all of {.var player_season}.",
        "x" = "{nrow(missing)} team{?s} unmapped.",
        "i" = "e.g. {.val {utils::head(missing$team, 3)}}"
      ))
    }
  }

  invisible(list(dim = agent_dim, coverage = agent_coverage))
}

#' Data contract for the draft-outcome join
#'
#' Guards the outcome-defining join in [link_drafted()]: it must be strictly
#' 1:1 on `playerId` (no fan-out from historical id collisions, decision 0011),
#' the `drafted` flag must be a complete logical, and any `draft_year` must fall
#' inside the stats window.
#'
#' @param ps_draft Player-seasons with the draft outcome attached (see
#'   [link_drafted()]).
#' @param player_season The pre-join backbone (see [build_player_season()]); its
#'   row count is the count `ps_draft` must preserve.
#' @param stop_on_fail Abort on failure (default `TRUE`)?
#' @return The interrogated pointblank agent, invisibly.
#' @export
contract_drafted <- function(ps_draft, player_season, stop_on_fail = TRUE) {
  rlang::check_installed("pointblank")
  ps_draft <- dplyr::collect(ps_draft)
  n_expected <- nrow(dplyr::collect(player_season))
  agent <- pointblank::create_agent(ps_draft, label = "drafted") |>
    pointblank::col_exists(c(
      "drafted",
      "draft_year",
      "draft_round",
      "draft_overall"
    )) |>
    # No fan-out: the join preserves the backbone row count exactly.
    pointblank::col_vals_equal("n", n_expected, preconditions = function(x) {
      dplyr::mutate(x, n = nrow(x))
    }) |>
    pointblank::col_vals_not_null(pointblank::vars(drafted)) |>
    pointblank::col_is_logical(pointblank::vars(drafted)) |>
    pointblank::col_vals_between(
      "draft_year",
      2010,
      2025,
      na_pass = TRUE
    ) |>
    pointblank::interrogate()
  enforce_contract(agent, "drafted", stop_on_fail)
}

#' Data contract for cleaned rosters
#'
#' @param roster Cleaned roster (see [clean_roster()]).
#' @param stop_on_fail Abort on failure (default `TRUE`)?
#' @return The interrogated pointblank agent, invisibly.
#' @export
contract_roster <- function(roster, stop_on_fail = TRUE) {
  rlang::check_installed("pointblank")
  agent <- pointblank::create_agent(roster, label = "roster") |>
    pointblank::col_exists(c("playerId", "season", "weight")) |>
    pointblank::col_vals_not_null(pointblank::vars(playerId, season)) |>
    pointblank::col_vals_between("weight", 100, 500, na_pass = TRUE) |>
    pointblank::interrogate()
  enforce_contract(agent, "roster", stop_on_fail)
}
