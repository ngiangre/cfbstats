# Cleaning: standardize schemas and coerce join keys onto the shared athlete-id
# namespace (decision 0003). Cleaning never mutates raw inputs; it returns new
# tibbles. Keep transformations minimal and legible so the audit layer
# (decision 0005) can attribute every row change.

#' Clean draft picks
#'
#' Coerces the (int) `collegeAthleteId` to a string `playerId` so picks join
#' directly to `player_stats.playerId` / `roster.id` (decision 0003). Retains
#' the original id for QA.
#'
#' @param picks Raw picks tibble from [ingest_picks()].
#'
#' @return A cleaned picks tibble with a string `playerId` key.
#' @export
clean_picks <- function(picks) {
  picks |>
    dplyr::mutate(
      playerId = dplyr::if_else(
        is.na(.data$collegeAthleteId),
        NA_character_,
        as.character(.data$collegeAthleteId)
      ),
      drafted = TRUE
    )
}

#' Clean player season stats
#'
#' Ensures key column types on the long player-season stats. Stays long; the
#' pivot to position-relevant features happens in the features stage.
#'
#' @param player_stats Raw long stats tibble from [ingest_player_stats()].
#'
#' @return A cleaned long player-season stats tibble.
#' @export
clean_player_stats <- function(player_stats) {
  player_stats |>
    dplyr::mutate(
      playerId = as.character(.data$playerId),
      season = as.integer(.data$season)
    )
}

#' Clean coaches
#'
#' Renames the unnested `seasons_*` columns to a tidy head-coach-season schema
#' and builds the `(school, season)` key used to join coaches to player-seasons.
#'
#' @param coaches Raw coaches tibble from [ingest_coaches()].
#'
#' @return A cleaned tibble, one row per head-coach-season.
#' @export
clean_coaches <- function(coaches) {
  coaches |>
    dplyr::transmute(
      coach_id = .data$id,
      coach_name = paste(.data$firstName, .data$lastName),
      school = .data$seasons_school,
      conference = .data$seasons_conference,
      season = as.integer(.data$seasons_year),
      games = .data$seasons_games,
      wins = .data$seasons_wins,
      losses = .data$seasons_losses,
      srs = .data$seasons_srs,
      sp_overall = .data$seasons_spOverall,
      sp_offense = .data$seasons_spOffense,
      sp_defense = .data$seasons_spDefense
    )
}

#' Clean rosters
#'
#' Standardizes roster physicals to the athlete-id key. Column names may vary by
#' CFBD version; this selects defensively via [dplyr::any_of()].
#'
#' @param roster Raw roster tibble from [ingest_roster()].
#'
#' @return A cleaned roster tibble keyed by string `playerId` and `season`.
#' @export
clean_roster <- function(roster) {
  roster |>
    dplyr::mutate(playerId = as.character(.data$id)) |>
    dplyr::select(
      "playerId",
      "season",
      dplyr::any_of(c(
        "team",
        "position",
        "height",
        "weight",
        "jersey",
        "class_year",
        home_state = "homeState",
        home_city = "homeCity"
      ))
    ) |>
    dplyr::mutate(season = as.integer(.data$season))
}
