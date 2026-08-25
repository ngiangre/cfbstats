# Ingestion: pure functions that pull raw CFBD data and return tibbles.
# Writing to disk / parquet is the pipeline's job (see _targets.R), not these
# functions'. Refactored from the original data-raw/DATASET.R (decision 0004).

#' Base CFBD API URL
#'
#' @return The CFBD API base URL as a string.
#' @keywords internal
cfbd_base_url <- function() {
  "https://api.collegefootballdata.com"
}

#' Perform an authenticated CFBD API request
#'
#' Thin wrapper over `httr2` that attaches the bearer token from the
#' `CFBD_API_KEY` environment variable and returns the parsed body as a tibble.
#'
#' @param endpoint API path, e.g. `"/draft/picks"`.
#' @param query Named list of query parameters (optional).
#'
#' @return A tibble of the (vector-simplified) JSON response.
#' @keywords internal
cfbd_get <- function(endpoint, query = list()) {
  rlang::check_installed(c("httr2", "tibble"), reason = "to call the CFBD API.")
  key <- Sys.getenv("CFBD_API_KEY")
  if (!nzchar(key)) {
    cli::cli_abort(
      "{.envvar CFBD_API_KEY} is not set; cannot call the CFBD API."
    )
  }
  req <- httr2::request(cfbd_base_url()) |>
    httr2::req_url_path_append(endpoint) |>
    httr2::req_headers(Authorization = paste("Bearer", key)) |>
    httr2::req_user_agent("cfbstats (https://github.com)")
  if (length(query)) {
    req <- httr2::req_url_query(req, !!!query)
  }
  req |>
    httr2::req_perform() |>
    httr2::resp_body_json(simplifyVector = TRUE) |>
    tibble::as_tibble()
}

#' Ingest NFL draft picks
#'
#' Pulls `/draft/picks` and unnests the nested `hometownInfo` block. The draft
#' outcome table; `collegeAthleteId` is the (int) athlete key that joins to
#' player stats once coerced to string (decision 0003).
#'
#' @return A tibble, one row per drafted player.
#' @export
ingest_picks <- function() {
  rlang::check_installed("tidyr")
  cfbd_get("/draft/picks") |>
    tidyr::unnest(cols = "hometownInfo", names_sep = "_")
}

#' Ingest player season stats for one or more years
#'
#' Pulls `/stats/player/season` per year. Returns **long** data: one row per
#' player-season-category-statType-stat (decision 0003 / VISION §4).
#'
#' @param years Integer vector of seasons (default 2010:2026).
#'
#' @return A long tibble of player-season stats across `years`.
#' @export
ingest_player_stats <- function(years = 2010:2026) {
  rlang::check_installed("purrr")
  purrr::map(
    as.integer(years),
    \(y) cfbd_get("/stats/player/season", query = list(year = y))
  ) |>
    purrr::list_rbind()
}

#' Ingest high-school recruiting ratings for one or more years
#'
#' Pulls `/recruiting/players` per year: one row per HS recruit with the
#' industry `stars` (2-5), composite `rating` (~0.74-1.0), and national
#' `ranking`. The `athleteId` (string) is the CFBD athlete key that joins to
#' [ingest_roster()]'s `id` and, coerced from int, `picks$collegeAthleteId`
#' (decision 0003 namespace). Recruits with no `athleteId` (~50%: never
#' enrolled, JUCO/international, or unlinked) cannot be joined and are kept as-is
#' here; filtering is a cleaning/feature concern.
#'
#' @param years Integer vector of recruiting classes (default 2010:2026).
#'
#' @return A flat tibble, one row per recruit, with `hometownInfo` unnested.
#' @export
ingest_recruiting <- function(years = 2010:2026) {
  rlang::check_installed(c("purrr", "tidyr"))
  purrr::map(
    as.integer(years),
    \(y) cfbd_get("/recruiting/players", query = list(year = y))
  ) |>
    purrr::list_rbind() |>
    tidyr::unnest(cols = "hometownInfo", names_sep = "_")
}

#' Ingest head coaches
#'
#' Pulls `/coaches` and unnests the per-season `seasons` block. Head coaches
#' only (no coordinators / S&C); one row per head-coach-season.
#'
#' @return A tibble, one row per head-coach-season.
#' @export
ingest_coaches <- function() {
  rlang::check_installed("tidyr")
  cfbd_get("/coaches") |>
    tidyr::unnest(cols = "seasons", names_sep = "_")
}

#' Ingest team metadata (logos, colors, conference)
#'
#' Pulls `/teams` — the team **dimension** table, one row per program with
#' display metadata (colors, mascot, abbreviation, conference). The raw `logos`
#' block is a list of the same image at several resolutions in light and `-dark`
#' variants; like the other ingest functions (which unnest `hometownInfo` /
#' `seasons`), this flattens it here into `logo_light` / `logo_dark` so the
#' persisted parquet stays flat. Deduping duplicate school names is a cleaning
#' concern, handled in [clean_teams()].
#'
#' @return A flat tibble, one row per team row returned by `/teams` (school names
#'   may still repeat until [clean_teams()] dedupes them).
#' @export
ingest_teams <- function() {
  rlang::check_installed("purrr")
  first_match <- function(x, pattern) {
    if (length(x)) x[grep(pattern, x)][1] else NA_character_
  }
  cfbd_get("/teams") |>
    dplyr::transmute(
      id = .data$id,
      school = .data$school,
      mascot = .data$mascot,
      abbreviation = .data$abbreviation,
      conference = .data$conference,
      classification = .data$classification,
      color = .data$color,
      alternateColor = .data$alternateColor,
      logo_light = purrr::map_chr(
        .data$logos,
        first_match,
        pattern = "/logos/"
      ),
      logo_dark = purrr::map_chr(
        .data$logos,
        first_match,
        pattern = "/logos-dark/"
      )
    )
}

#' Ingest team rosters for one or more years
#'
#' Pulls `/roster` per year for per-season physicals (height, **weight**),
#' position, jersey, and hometown, keyed by athlete `id`. New for decision 0003:
#' the source for weight-change features and a full player-season backbone
#' (includes players with no qualifying stat line).
#'
#' The `season` is stamped from the queried year: the endpoint's own `year`
#' field is the player's **eligibility class** (1-5), not the season, so it is
#' renamed to `class_year` and never used as the season key.
#'
#' @param years Integer vector of seasons (default 2010:2026).
#'
#' @return A tibble, one row per player-season on a roster, with an authoritative
#'   `season` column.
#' @export
ingest_roster <- function(years = 2010:2026) {
  rlang::check_installed(c("purrr", "dplyr"))
  purrr::map(
    as.integer(years),
    \(y) {
      cfbd_get("/roster", query = list(year = y)) |>
        dplyr::rename(dplyr::any_of(c(class_year = "year"))) |>
        dplyr::mutate(season = y)
    }
  ) |>
    purrr::list_rbind()
}
