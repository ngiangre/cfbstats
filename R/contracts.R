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
    pointblank::col_exists(c("coach_id", "school", "season", "srs")) |>
    pointblank::col_vals_not_null(pointblank::vars(coach_id, school, season)) |>
    pointblank::col_vals_between("season", 1869, 2026) |>
    pointblank::interrogate()
  enforce_contract(agent, "coaches", stop_on_fail)
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
    pointblank::col_vals_between("weight", 100, 450, na_pass = TRUE) |>
    pointblank::interrogate()
  enforce_contract(agent, "roster", stop_on_fail)
}
