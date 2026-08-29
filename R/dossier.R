# Player dossier: assemble one player's college-through-NFL record into an
# interpretable, faithful extract. The point is *interpretation* — stats grouped
# by game phase with plain-language labels (never a bare "TD"), coaching context
# with an explicit "not available" where the FBS-only feed is blank, recruiting
# as a real "unrated" category, a data-backed drafted/undrafted-signed outcome,
# and a provenance block so a reviewer can validate rather than guess. It never
# fabricates: absences are labeled, not imputed.

#' Assemble an interpretable player dossier
#'
#' Builds a structured, human-readable record for a single college player keyed
#' on the CFBD athlete id (the shared `player_stats$playerId` / `roster$playerId`
#' namespace, decision 0003). Returns a `cfb_dossier` object with tidy tables per
#' section plus a `print()` method for handing to a reviewer.
#'
#' Design commitments:
#' * **Stats are grouped by phase** (offense / defense / special_teams) and
#'   labeled via [stat_taxonomy()], so "TD" is disambiguated into e.g. "Passing
#'   touchdowns" vs "Defensive touchdowns".
#' * **Coaching context is explicit about coverage**: the CFBD coaches feed is
#'   FBS head-coaches only, so a player-season with no coach row is marked
#'   `coach_available = FALSE` ("not in CFBD feed — non-FBS / missing"), not a
#'   silent `NA`.
#' * **Recruiting** uses the name-guarded rating (decision 0013); a genuinely
#'   unrated player stays "unrated" rather than imputed.
#' * **Outcome** is resolved by [resolve_nfl_outcome()] — drafted or
#'   undrafted-signed — and is an outcome/label kept off the model path.
#'
#' @param id CFBD athlete id (coerced to string).
#' @param player_stats Cleaned long `player_stats`.
#' @param roster Cleaned `roster`.
#' @param coaches Cleaned `coaches` (FBS head coaches only).
#' @param picks_nfl CFBD picks bridged to nflverse ([link_nfl_draft()]).
#' @param recruiting Cleaned `recruiting`.
#' @param nfl_rosters,nfl_player_stats Cleaned nflverse tables (longevity source).
#' @param teams Optional cleaned `teams` dimension (display metadata); if
#'   supplied, the team `mascot` is attached to the identity block.
#' @param taxonomy Stat-phase taxonomy; defaults to [stat_taxonomy()].
#'
#' @return An object of class `cfb_dossier`: a named list with `id`, `identity`,
#'   `stats` (tidy, phase-labeled), `coaching`, `recruiting`, `outcome`, and
#'   `provenance`.
#' @export
player_dossier <- function(
  id,
  player_stats,
  roster,
  coaches,
  picks_nfl,
  recruiting,
  nfl_rosters,
  nfl_player_stats,
  teams = NULL,
  taxonomy = stat_taxonomy()
) {
  id <- as.character(id)

  ps <- player_stats |>
    dplyr::mutate(playerId = as.character(.data$playerId)) |>
    dplyr::filter(.data$playerId == id) |>
    dplyr::collect()
  if (nrow(ps) == 0) {
    cli::cli_abort("No {.field player_stats} rows for playerId {.val {id}}.")
  }
  nm <- ps$player[!is.na(ps$player)][1]
  last_season <- max(ps$season, na.rm = TRUE)
  team_seasons <- ps |>
    dplyr::distinct(.data$season, .data$team, .data$conference) |>
    dplyr::arrange(.data$season)
  last_team <- team_seasons$team[team_seasons$season == last_season][1]

  # ---- identity ----
  ros <- roster |>
    dplyr::mutate(playerId = as.character(.data$playerId)) |>
    dplyr::filter(.data$playerId == id) |>
    dplyr::collect() |>
    dplyr::arrange(dplyr::desc(.data$season))
  latest_ros <- if (nrow(ros)) ros[1, ] else ros
  mascot <- NA_character_
  if (!is.null(teams)) {
    tm <- dplyr::collect(teams)
    mascot <- tm$mascot[match(last_team, tm$team)]
  }
  identity <- tibble::tibble(
    playerId = id,
    player = nm,
    position = paste(sort(unique(stats_positions(ps))), collapse = ", "),
    seasons = paste0(min(ps$season), "-", max(ps$season)),
    n_seasons = dplyr::n_distinct(ps$season),
    teams = paste(unique(team_seasons$team), collapse = ", "),
    last_team = last_team,
    mascot = mascot,
    height_in = if (nrow(latest_ros)) latest_ros$height else NA_real_,
    weight_lb = if (nrow(latest_ros)) latest_ros$weight else NA_integer_,
    hometown = if (nrow(latest_ros)) {
      paste_hometown(latest_ros$home_city, latest_ros$home_state)
    } else {
      NA_character_
    }
  )

  # ---- stats by phase (labeled) ----
  stats <- ps |>
    dplyr::transmute(
      .data$season,
      .data$team,
      .data$category,
      .data$statType,
      .data$stat
    ) |>
    label_stats(taxonomy) |>
    dplyr::mutate(value = suppressWarnings(as.numeric(.data$stat))) |>
    dplyr::arrange(.data$season, .data$phase, .data$category, .data$statType)

  # ---- coaching (explicit coverage) ----
  coaches_c <- dplyr::collect(coaches)
  coaching <- team_seasons |>
    dplyr::distinct(.data$season, .data$team) |>
    dplyr::left_join(
      dplyr::rename(coaches_c, team = "school"),
      by = c("team", "season"),
      relationship = "many-to-many"
    ) |>
    dplyr::mutate(coach_available = !is.na(.data$coach_id)) |>
    dplyr::select(
      "season",
      "team",
      coach = "coach_name",
      "wins",
      "losses",
      "coach_available"
    ) |>
    dplyr::arrange(.data$season)

  # ---- recruiting (name-guarded; unrated stays unrated) ----
  recruiting_row <- link_recruiting(
    tibble::tibble(playerId = id, player = nm),
    dplyr::collect(recruiting)
  )

  # ---- outcome (drafted or undrafted-signed) ----
  outcome <- resolve_nfl_outcome(
    tibble::tibble(
      playerId = id,
      player = nm,
      college = last_team,
      last_college_season = last_season
    ),
    picks_nfl,
    nfl_rosters,
    nfl_player_stats
  )

  # ---- provenance / caveats ----
  n_no_coach <- sum(!coaching$coach_available)
  provenance <- tibble::tibble(
    section = c("stats", "coaching", "recruiting", "outcome"),
    source = c(
      "CFBD /stats/player/season (long) + stat_taxonomy phase labels",
      "CFBD /coaches (FBS head coaches only; no FCS, no coordinators)",
      "CFBD /recruiting/players (name-guarded, decision 0013)",
      "CFBD picks (draft slot) + nflverse rosters/stats (name-guarded UDFA)"
    ),
    note = c(
      "Phase/label from (category, statType); values as reported by CFBD.",
      if (n_no_coach > 0) {
        paste0(
          n_no_coach,
          " of ",
          nrow(coaching),
          " team-seasons have no CFBD head coach (non-FBS or missing)."
        )
      } else {
        "Head coach resolved for every team-season."
      },
      if (isTRUE(recruiting_row$recruit_matched)) {
        "HS rating matched by name."
      } else {
        "No name-matched HS rating; treat as unrated (not imputed)."
      },
      paste0(
        outcome$note,
        if (isTRUE(outcome$right_censored)) {
          " Longevity is right-censored (player may still be active)."
        } else {
          ""
        }
      )
    )
  )

  structure(
    list(
      id = id,
      identity = identity,
      stats = stats,
      coaching = coaching,
      recruiting = recruiting_row,
      outcome = outcome,
      provenance = provenance
    ),
    class = "cfb_dossier"
  )
}

# Positions observed in a player's stat lines (helper).
stats_positions <- function(ps) {
  pos <- ps$position
  pos <- pos[!is.na(pos) & nzchar(pos)]
  if (length(pos)) pos else NA_character_
}

# Join a city/state into a hometown string, tolerating missing parts.
paste_hometown <- function(city, state) {
  parts <- c(city, state)
  parts <- parts[!is.na(parts) & nzchar(parts)]
  if (length(parts)) paste(parts, collapse = ", ") else NA_character_
}

# Format stat values for display: whole numbers (counts like TDs, yards) print
# as integers, fractional values (rates like completion % or yards/attempt) to
# two decimals — so a count reads "16", not "16.000".
fmt_value <- function(v) {
  out <- formatC(v, format = "f", digits = 2)
  whole <- !is.na(v) & v == round(v)
  out[whole] <- formatC(v[whole], format = "d")
  out[is.na(v)] <- NA_character_
  out
}

#' @export
print.cfb_dossier <- function(x, ...) {
  id <- x$identity
  cat("== Player dossier:", id$player, paste0("(id ", x$id, ") =="), "\n")
  cat(sprintf(
    "  %s | %s | %s\n",
    id$position,
    paste0(id$teams, " (", id$seasons, ")"),
    if (!is.na(id$hometown)) id$hometown else "hometown NA"
  ))
  phys <- c(
    if (!is.na(id$height_in)) sprintf("%.0f in", id$height_in),
    if (!is.na(id$weight_lb)) sprintf("%d lb", id$weight_lb)
  )
  if (length(phys)) {
    cat("  Physicals:", paste(phys, collapse = ", "), "\n")
  }

  # Stats grouped by phase, per season.
  cat("\n-- College statistics (by phase) --\n")
  st <- x$stats[!is.na(x$stats$phase), ]
  for (s in sort(unique(st$season))) {
    ss <- st[st$season == s, ]
    cat(sprintf("  %d (%s):\n", s, ss$team[1]))
    for (ph in c("offense", "defense", "special_teams")) {
      pp <- ss[ss$phase == ph & !is.na(ss$value) & ss$value != 0, ]
      if (nrow(pp) == 0) {
        next
      }
      lines <- paste0(pp$label, " ", fmt_value(pp$value))
      cat(sprintf("    %-15s %s\n", ph, paste(lines, collapse = " | ")))
    }
  }

  # Coaching.
  cat("\n-- Coaching context --\n")
  for (i in seq_len(nrow(x$coaching))) {
    r <- x$coaching[i, ]
    if (isTRUE(r$coach_available)) {
      cat(sprintf(
        "  %d %s: %s (%s-%s)\n",
        r$season,
        r$team,
        r$coach,
        r$wins,
        r$losses
      ))
    } else {
      cat(sprintf(
        "  %d %s: head coach not available (non-FBS / not in CFBD feed)\n",
        r$season,
        r$team
      ))
    }
  }

  # Recruiting.
  rec <- x$recruiting
  cat("\n-- Recruiting --\n")
  if (isTRUE(rec$recruit_matched)) {
    cat(sprintf(
      "  HS: %s stars, rating %s (national rank %s)\n",
      rec$hs_stars,
      rec$hs_rating,
      rec$hs_national_rank
    ))
  } else {
    cat("  Unrated (no name-matched HS recruiting record).\n")
  }

  # Outcome.
  o <- x$outcome
  cat("\n-- NFL outcome --\n")
  if (o$nfl_status == "drafted") {
    cat(sprintf(
      "  Drafted %d, round %s, overall %s.\n",
      o$draft_year,
      o$draft_round,
      o$draft_overall
    ))
  } else if (o$nfl_status == "undrafted-signed") {
    cat("  Undrafted, signed to an NFL roster.\n")
  } else {
    cat("  No NFL record found.\n")
  }
  if (!is.na(o$nfl_seasons)) {
    cat(sprintf(
      "  NFL longevity: %d roster season(s), %s-%s%s%s.\n",
      o$nfl_seasons,
      o$nfl_first_season,
      o$nfl_last_season,
      if (!is.na(o$nfl_games)) sprintf(", %d games", o$nfl_games) else "",
      if (isTRUE(o$right_censored)) " (right-censored)" else ""
    ))
  }
  cat(sprintf("  Match method: %s\n", o$nfl_match_method))

  # Provenance.
  cat("\n-- Provenance & caveats --\n")
  for (i in seq_len(nrow(x$provenance))) {
    p <- x$provenance[i, ]
    cat(sprintf("  [%s] %s\n      %s\n", p$section, p$source, p$note))
  }
  invisible(x)
}
