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
    x = ~draft_year, y = ~n_drafted, type = "scatter", mode = "lines+markers"
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
    x = {{ x }}, y = {{ y }}, tooltip = {{ tooltip }}, data_id = {{ tooltip }}
  )
  if (!rlang::quo_is_null(rlang::enquo(color))) {
    mapping$colour <- ggplot2::aes(colour = {{ color }})$colour
  }
  p <- ggplot2::ggplot(data, mapping) +
    ggiraph::geom_point_interactive(alpha = 0.7) +
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
    data = data, x = stats::as.formula(paste0("~", x)),
    y = stats::as.formula(paste0("~", y)),
    z = stats::as.formula(paste0("~", z)),
    type = "scatter3d", mode = "markers",
    marker = list(size = 3)
  )
  if (!is.null(color)) args$color <- stats::as.formula(paste0("~", color))
  do.call(plotly::plot_ly, args)
}
