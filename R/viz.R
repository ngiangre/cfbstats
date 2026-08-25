# Visualization helpers (decision 0006). R htmlwidgets are the default stack;
# these helpers keep charts themed consistently and traceable to a single
# pipeline target. Observable JS is reserved for bespoke explorables on the site.

#' Shared ggplot2 theme
#'
#' @return A ggplot2 theme object (falls back silently if ggplot2 is absent).
#' @export
viz_theme <- function() {
  rlang::check_installed("ggplot2")
  ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      plot.title.position = "plot"
    )
}

#' Time series: drafted players per season (interactive)
#'
#' @param player_season Modeling table with `season` and logical `drafted`.
#' @return A `plotly` htmlwidget line chart of drafted counts by season.
#' @export
viz_drafts_by_season <- function(player_season) {
  rlang::check_installed("plotly")
  d <- player_season |>
    dplyr::filter(.data$drafted) |>
    dplyr::distinct(.data$playerId, .data$draft_year) |>
    dplyr::count(.data$draft_year, name = "n_drafted") |>
    dplyr::arrange(.data$draft_year)
  plotly::plot_ly(
    d,
    x = ~draft_year,
    y = ~n_drafted,
    type = "scatter",
    mode = "lines+markers"
  ) |>
    plotly::layout(
      title = "Drafted players by draft year",
      xaxis = list(title = "Draft year"),
      yaxis = list(title = "Players drafted")
    )
}

#' 2D interactive scatter (tooltip on hover) via ggiraph
#'
#' @param data A data frame.
#' @param x,y Bare column names for axes.
#' @param tooltip Bare column name for the hover tooltip.
#' @param color Optional bare column name for color.
#' @return A `ggiraph` (girafe) htmlwidget.
#' @export
viz_scatter_2d <- function(data, x, y, tooltip, color = NULL) {
  rlang::check_installed(c("ggplot2", "ggiraph"))
  mapping <- ggplot2::aes(
    x = {{ x }},
    y = {{ y }},
    tooltip = {{ tooltip }},
    data_id = {{ tooltip }}
  )
  if (!rlang::quo_is_null(rlang::enquo(color))) {
    mapping$colour <- ggplot2::aes(colour = {{ color }})$colour
  }
  p <- ggplot2::ggplot(data, mapping) +
    ggiraph::geom_point_interactive(alpha = 0.7) +
    viz_theme()
  ggiraph::girafe(ggobj = p)
}

#' Team logo table (reactable)
#'
#' Renders the team dimension ([clean_teams()]) as a searchable table with logo
#' thumbnails and brand-color swatches. A minimal "does the logo render" view for
#' the site; logos are display metadata joined by school name (decision 0008).
#'
#' @param teams Cleaned team dimension with `logo_light`, `color`, `alt_color`.
#' @param n Maximum number of teams to show (default 25).
#' @return A `reactable` htmlwidget.
#' @export
viz_team_logos <- function(teams, n = 25) {
  rlang::check_installed(c("reactable", "htmltools"))
  swatch <- function(value) {
    if (is.na(value)) {
      return("")
    }
    htmltools::div(
      style = sprintf(
        "width:16px;height:16px;border-radius:3px;border:1px solid #ccc;background:%s;",
        value
      )
    )
  }
  teams |>
    dplyr::filter(!is.na(.data$logo_light)) |>
    dplyr::arrange(.data$team) |>
    utils::head(n) |>
    dplyr::select(
      "logo_light",
      "team",
      "conference",
      "color",
      "alt_color"
    ) |>
    reactable::reactable(
      searchable = TRUE,
      striped = TRUE,
      defaultPageSize = 10,
      columns = list(
        logo_light = reactable::colDef(
          name = "",
          width = 60,
          cell = function(value) {
            htmltools::img(src = value, height = "28", alt = "")
          }
        ),
        team = reactable::colDef(name = "Team"),
        conference = reactable::colDef(name = "Conference"),
        color = reactable::colDef(name = "Color", width = 70, cell = swatch),
        alt_color = reactable::colDef(name = "Alt", width = 70, cell = swatch)
      )
    )
}

#' Drafted players per team, branded (ggiraph)
#'
#' Interactive horizontal bar of the top teams by drafted players, filled with
#' each team's own brand color and showing its logo on hover — a second logo
#' rendering path (ggiraph) that also exercises [link_team_meta()].
#'
#' @param model_table Modeling table with logical `drafted`, `playerId`, `team`.
#' @param teams Cleaned team dimension from [clean_teams()].
#' @param n Number of teams to show (default 15).
#' @return A `ggiraph` (girafe) htmlwidget.
#' @export
viz_drafts_by_team <- function(model_table, teams, n = 15) {
  rlang::check_installed(c("ggplot2", "ggiraph"))
  d <- model_table |>
    dplyr::filter(.data$drafted) |>
    dplyr::distinct(.data$playerId, .data$team) |>
    dplyr::count(.data$team, name = "n_drafted", sort = TRUE) |>
    utils::head(n) |>
    link_team_meta(teams) |>
    dplyr::mutate(
      fill = dplyr::coalesce(.data$color, "#4c78a8"),
      tooltip = ifelse(
        is.na(.data$logo_light),
        sprintf("%s: %d", .data$team, .data$n_drafted),
        sprintf(
          "<img src='%s' height='40'><br><b>%s</b>: %d drafted",
          .data$logo_light,
          .data$team,
          .data$n_drafted
        )
      )
    )
  p <- ggplot2::ggplot(
    d,
    ggplot2::aes(
      x = .data$n_drafted,
      y = stats::reorder(.data$team, .data$n_drafted),
      fill = .data$fill
    )
  ) +
    ggiraph::geom_col_interactive(
      ggplot2::aes(tooltip = .data$tooltip, data_id = .data$team)
    ) +
    ggplot2::scale_fill_identity() +
    ggplot2::labs(
      x = "Players drafted",
      y = NULL,
      title = "Most drafted players by team"
    ) +
    viz_theme()
  ggiraph::girafe(ggobj = p)
}

#' NFL roster-seasons (career length) by draft round, #1 overall highlighted
#'
#' For drafted players bridged to nflverse (decision 0014), plots the number of
#' distinct NFL seasons each spent on a roster — the project's primary longevity
#' measure — against draft round, with the **#1 overall picks** emphasized
#' against the rest of the field. Interactive: hover a point for the player and
#' their roster-season count. A per-round median crossbar aids comparison.
#'
#' Longevity is **right-censored** for recent draft classes still active, so
#' those picks' counts are lower bounds, not completed careers.
#'
#' @param picks_nfl CFBD picks bridged to nflverse (see [link_nfl_draft()]);
#'   needs `nfl_matched`, `round`, `overall`, `name`, `year`, `gsis_id`,
#'   `playerId`.
#' @param nfl_rosters Cleaned NFL rosters (see [clean_nfl_rosters()]); roster
#'   seasons are counted as distinct `season` per `gsis_id`.
#' @return A `ggiraph` (girafe) htmlwidget.
#' @export
viz_nfl_roster_seasons_by_round <- function(picks_nfl, nfl_rosters) {
  rlang::check_installed(c("ggplot2", "ggiraph"))
  roster_seasons <- nfl_rosters |>
    dplyr::distinct(.data$gsis_id, .data$season) |>
    dplyr::count(.data$gsis_id, name = "roster_seasons")
  d <- picks_nfl |>
    dplyr::filter(.data$nfl_matched, !is.na(.data$round)) |>
    dplyr::left_join(roster_seasons, by = "gsis_id") |>
    dplyr::mutate(
      roster_seasons = dplyr::coalesce(.data$roster_seasons, 0L),
      pick_group = dplyr::if_else(
        .data$overall == 1,
        "#1 overall pick",
        "Other picks"
      ),
      tooltip = sprintf(
        "%s (%d, R%d #%d): %d NFL season%s on a roster",
        .data$name,
        .data$year,
        .data$round,
        .data$overall,
        .data$roster_seasons,
        dplyr::if_else(.data$roster_seasons == 1L, "", "s")
      )
    ) |>
    # Draw the #1 picks last so they sit on top of the field.
    dplyr::arrange(.data$pick_group == "#1 overall pick")
  p <- ggplot2::ggplot(
    d,
    ggplot2::aes(x = factor(.data$round), y = .data$roster_seasons)
  ) +
    ggplot2::stat_summary(
      fun = stats::median,
      fun.min = stats::median,
      fun.max = stats::median,
      geom = "crossbar",
      width = 0.6,
      colour = "grey40",
      linewidth = 0.3
    ) +
    ggiraph::geom_point_interactive(
      ggplot2::aes(
        tooltip = .data$tooltip,
        data_id = .data$playerId,
        colour = .data$pick_group,
        size = .data$pick_group
      ),
      position = ggplot2::position_jitter(width = 0.25, height = 0, seed = 7),
      alpha = 0.75
    ) +
    ggplot2::scale_colour_manual(
      values = c("#1 overall pick" = "#d1495b", "Other picks" = "#b0b7c0"),
      name = NULL
    ) +
    ggplot2::scale_size_manual(
      values = c("#1 overall pick" = 3.4, "Other picks" = 1.4),
      guide = "none"
    ) +
    ggplot2::labs(
      x = "Draft round",
      y = "NFL seasons on a roster",
      title = "How long drafted players last in the NFL, by draft round",
      subtitle = "#1 overall picks highlighted; recent classes are right-censored"
    ) +
    viz_theme()
  ggiraph::girafe(ggobj = p)
}

#' 3D interactive scatter via plotly
#'
#' @param data A data frame.
#' @param x,y,z Column-name strings for the three axes.
#' @param color Optional column-name string mapped to color.
#' @return A `plotly` 3D scatter htmlwidget.
#' @export
viz_scatter_3d <- function(data, x, y, z, color = NULL) {
  rlang::check_installed("plotly")
  args <- list(
    data = data,
    x = stats::as.formula(paste0("~", x)),
    y = stats::as.formula(paste0("~", y)),
    z = stats::as.formula(paste0("~", z)),
    type = "scatter3d",
    mode = "markers",
    marker = list(size = 3)
  )
  if (!is.null(color)) {
    args$color <- stats::as.formula(paste0("~", color))
  }
  do.call(plotly::plot_ly, args)
}
