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

#' Clean team metadata
#'
#' Standardizes the `/teams` dimension for a **name join** on `team` (= CFBD
#' `school`), which is the same namespace as `player_stats.team` and the coach
#' join (decision 0008). The key cleaning step is **deduping to one row per
#' school**: `/teams` contains duplicate school names (a real program plus a
#' phantom row with `NA` classification and no logos); a naive join would fan
#' out. We keep the row with a real `classification`, then the one that has a
#' logo, dropping the phantom. Logo URLs were flattened at ingest; a handful of
#' small programs carry no logo and are left `NA` (placeholder at display time).
#'
#' @param teams Raw teams tibble from [ingest_teams()] (already flat).
#'
#' @return A cleaned tibble, one row per `team`, with colors and logo URLs.
#' @export
clean_teams <- function(teams) {
  teams |>
    # Prefer the real program (non-NA classification), then the row with a logo.
    dplyr::arrange(
      .data$school,
      is.na(.data$classification),
      is.na(.data$logo_light)
    ) |>
    dplyr::distinct(.data$school, .keep_all = TRUE) |>
    dplyr::transmute(
      team = .data$school,
      team_id = .data$id,
      mascot = .data$mascot,
      abbreviation = .data$abbreviation,
      conference = .data$conference,
      classification = .data$classification,
      color = .data$color,
      alt_color = .data$alternateColor,
      logo_light = .data$logo_light,
      logo_dark = .data$logo_dark
    )
}

#' Clean rosters
#'
#' Standardizes roster physicals to the athlete-id key. Column names may vary by
#' CFBD version; this selects defensively via [dplyr::any_of()].
#'
#' A listed `weight` of `0` is an impossible value used as a missing-data
#' placeholder in `/roster`, so it is coerced to `NA` (decision 0009 Outcome).
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
    dplyr::mutate(
      season = as.integer(.data$season),
      dplyr::across(
        dplyr::any_of("weight"),
        \(w) dplyr::if_else(w == 0, NA_integer_, as.integer(w))
      )
    )
}

#' Clean high-school recruiting ratings
#'
#' Standardizes the raw recruiting feed to a **per-athlete** rating table keyed
#' by the string `playerId` (from `athleteId`). Recruits with no `athleteId`
#' cannot join the athlete-id namespace (decision 0003) and are dropped here
#' (~40% of the feed: never enrolled, JUCO/international, or unlinked).
#' Deduplicates to one row per athlete, keeping the highest `rating` (then
#' `stars`, then most recent class) since a player can appear in more than one
#' record/class — the same dedupe philosophy as [clean_teams()].
#'
#' The recruiting `athleteId` is **not** a reliable member of the shared
#' athlete-id namespace: it collides across different people (decision 0013), so
#' the join this table feeds must be name-guarded — see [link_recruiting()].
#'
#' @param recruiting Raw recruiting tibble from [ingest_recruiting()].
#'
#' @return A cleaned tibble, one row per recruited athlete, keyed by `playerId`.
#' @export
clean_recruiting <- function(recruiting) {
  recruiting |>
    dplyr::filter(!is.na(.data$athleteId)) |>
    dplyr::transmute(
      playerId = as.character(.data$athleteId),
      recruit_name = .data$name,
      hs_class = as.integer(.data$year),
      stars = as.integer(.data$stars),
      rating = as.double(.data$rating),
      national_rank = as.integer(.data$ranking),
      recruit_position = .data$position,
      committed_to = .data$committedTo
    ) |>
    dplyr::arrange(
      .data$playerId,
      dplyr::desc(.data$rating),
      dplyr::desc(.data$stars),
      dplyr::desc(.data$hs_class)
    ) |>
    dplyr::distinct(.data$playerId, .keep_all = TRUE)
}
