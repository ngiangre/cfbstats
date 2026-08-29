# Bundle the cleaned tables into a single queryable DuckDB file (decision 0016).
# Built as the `duckdb_file` pipeline target (see _targets.R) so it is part of
# the DAG and rebuilt whenever an upstream table changes; published alongside
# the parquet on the `data-latest` release. It carries the CLEANED,
# contract-checked tables — the schemas documented in inst/dict/*.yml — not the
# raw ingest parquet.

#' Bundle cleaned tables into a queryable DuckDB database
#'
#' Writes each supplied data frame as a table in a single DuckDB database file,
#' so the whole cfbstats data model can be explored with SQL from one asset
#' (decision 0016). The database is rebuilt from scratch on each call so a
#' dropped or renamed table never lingers. Intended to run as the `duckdb_file`
#' target: it bundles the cleaned tables whose schemas are documented in
#' `inst/dict/*.yml`.
#'
#' @param tables A named list of data frames. Each name becomes a DuckDB table
#'   (e.g. `conference_tiers = tiers`).
#' @param db_path Output DuckDB file path.
#'
#' @return `db_path`, invisibly (so the target can track it with
#'   `format = "file"`).
#' @export
build_duckdb <- function(tables, db_path = "data/cfbstats.duckdb") {
  rlang::check_installed(
    c("DBI", "duckdb"),
    reason = "to build the DuckDB data asset."
  )
  if (
    !length(tables) || is.null(names(tables)) || any(!nzchar(names(tables)))
  ) {
    cli::cli_abort("{.arg tables} must be a non-empty {.emph named} list.")
  }

  dir.create(dirname(db_path), showWarnings = FALSE, recursive = TRUE)
  # Rebuild from scratch so a dropped/renamed table never lingers.
  if (file.exists(db_path)) {
    file.remove(db_path)
  }
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  for (name in names(tables)) {
    DBI::dbWriteTable(
      con,
      name,
      as.data.frame(tables[[name]]),
      overwrite = TRUE
    )
  }

  cli::cli_alert_success(
    "Built DuckDB {.path {db_path}} with {length(tables)} table{?s}: {.val {names(tables)}}."
  )
  invisible(db_path)
}
