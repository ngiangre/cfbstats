# Linking: assemble the player-season backbone and attach coach, conference-tier,
# and draft-outcome context by joining on stable keys (athlete id; school+season).
# Left joins throughout so the audit layer (decision 0005) can flag any silent
# row loss or unmatched keys.

#' Build the player-season backbone
#'
#' Collapses the long stats to one identity row per player-season-team
#' (dropping the category/statType/stat columns). This is the grain the
#' longitudinal change features and the draft outcome attach to.
#'
#' @param player_stats Cleaned long stats from [clean_player_stats()].
#'
#' @return A tibble, one row per `(playerId, season, team)`.
#' @export
build_player_season <- function(player_stats) {
  player_stats |>
    dplyr::distinct(
      .data$playerId,
      .data$player,
      .data$season,
      .data$team,
      .data$conference,
      .data$position
    )
}

#' Attach head-coach context to player-seasons
#'
#' Left-joins coaches on `school == team` and `season`. May introduce >1 row per
#' player-season if a school had multiple head coaches recorded in a year; the
#' audit layer reports any such row inflation.
#'
#' @param player_season Player-season backbone from [build_player_season()].
#' @param coaches Cleaned coaches from [clean_coaches()].
#'
#' @return `player_season` with coach columns attached.
#' @export
link_coaches <- function(player_season, coaches) {
  player_season |>
    dplyr::left_join(
      dplyr::rename(coaches, team = "school"),
      by = c("team", "season"),
      suffix = c("", "_coach"),
      # A school can have >1 head coach in a season (midseason changes); this
      # intentionally fans out and the audit layer reports the row inflation.
      relationship = "many-to-many"
    )
}

#' Attach season-aware conference tier
#'
#' Left-joins the `(season, conference) -> tier` lookup (decision 0003). Coverage
#' is guaranteed by [contract_conference_tiers()]; run that contract in the
#' pipeline so unmapped conferences fail fast rather than silently `NA`.
#'
#' @param player_season Player-season table with `season` and `conference`.
#' @param tiers Conference-tier lookup (`data/conference_tiers.parquet`).
#'
#' @return `player_season` with `tier` and `tier_label` attached.
#' @export
link_tiers <- function(player_season, tiers) {
  player_season |>
    dplyr::left_join(
      dplyr::select(tiers, "season", "conference", "tier", "tier_label"),
      by = c("season", "conference")
    )
}

#' Attach team display metadata (logos, colors)
#'
#' Left-joins the team dimension ([clean_teams()]) onto any table carrying a
#' `team` column, on the shared school-name key. This is a **display** helper for
#' the site/report (logos, colors), deliberately kept off the model path so logo
#' URLs never leak into features. Coverage is guaranteed by [contract_teams()];
#' a few small programs carry `NA` logo URLs (use a placeholder when rendering).
#'
#' @param x A table with a `team` column (e.g. the player-season backbone).
#' @param teams Cleaned team dimension from [clean_teams()].
#'
#' @return `x` with `logo_light`, `logo_dark`, `color`, `alt_color`, and team
#'   `mascot`/`abbreviation` attached.
#' @export
link_team_meta <- function(x, teams) {
  x |>
    dplyr::left_join(
      dplyr::select(
        teams,
        "team",
        "mascot",
        "abbreviation",
        "color",
        "alt_color",
        "logo_light",
        "logo_dark"
      ),
      by = "team"
    )
}

#' Attach the draft outcome
#'
#' Marks each player-season with whether that athlete was ever drafted and, if
#' so, the draft year/round/overall. Joins on the shared string `playerId`
#' (decision 0003). Outcome definition is refined in the features/model stages
#' (draft-eligible seasons only; out-of-time framing).
#'
#' `picks` carries the full NFL draft history (back to 1936) and CFBD reuses
#' `collegeAthleteId` across eras, so a modern player's id can match a pick from
#' decades earlier. Left unchecked that fans out the join (duplicating a
#' player-season) and falsely attributes an ancient draft to a current player
#' (decision 0011). Since a 2010-2026 college career can only lead to a
#' 2010-2027 draft, picks outside `draft_window` are dropped before the join —
#' this removes the pre-window collision artifacts entirely. The lookup is then
#' collapsed to **one pick per `playerId`** (most recent, a guard against any
#' future intra-window collision), so the join is strictly 1:1 on `playerId`,
#' adds no rows, and marks `drafted` only for a plausible in-window pick.
#'
#' @param player_season Player-season backbone.
#' @param picks Cleaned picks from [clean_picks()].
#' @param draft_window Integer vector of plausible draft years for players in
#'   the backbone; picks outside it are ignored. Defaults to `2010:2027` (the
#'   2010-2026 stats window plus the following spring's draft).
#'
#' @return `player_season` with `drafted`, `draft_year`, `draft_round`,
#'   `draft_overall`. Same row count as `player_season`.
#' @export
link_drafted <- function(player_season, picks, draft_window = 2010:2027) {
  draft_lookup <- picks |>
    dplyr::filter(
      !is.na(.data$playerId),
      .data$year %in% draft_window
    ) |>
    dplyr::transmute(
      .data$playerId,
      draft_year = .data$year,
      draft_round = .data$round,
      draft_overall = .data$overall
    ) |>
    # Guard against any future intra-window id collision: keep the most recent
    # pick so the lookup is one row per player (decision 0011).
    dplyr::arrange(.data$playerId, dplyr::desc(.data$draft_year)) |>
    dplyr::distinct(.data$playerId, .keep_all = TRUE)
  player_season |>
    dplyr::left_join(draft_lookup, by = "playerId") |>
    dplyr::mutate(drafted = !is.na(.data$draft_year))
}
