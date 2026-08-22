# Lineage / audit layer (decision 0005). A uniform, per-step record of what each
# transform did to the data so any statistic or prediction can be traced back to
# the rows and code that produced it, and silent row loss / schema drift is
# caught the moment it happens.

#' Hash a data frame's schema
#'
#' A stable digest of column names and types, used to detect schema drift across
#' data refreshes (decision 0005).
#'
#' @param data A data frame.
#'
#' @return A short character hash.
#' @export
schema_hash <- function(data) {
  spec <- paste(names(data), vapply(data, \(x) class(x)[1], character(1)),
    sep = ":", collapse = "|"
  )
  substr(rlang::hash(spec), 1, 12)
}

#' Best-effort current git SHA
#'
#' @return The short HEAD SHA, or `NA` if unavailable.
#' @keywords internal
current_git_sha <- function() {
  tryCatch(
    {
      if (requireNamespace("gert", quietly = TRUE)) {
        substr(gert::git_log(max = 1)$commit, 1, 12)
      } else {
        NA_character_
      }
    },
    error = \(e) NA_character_
  )
}

#' Record an audit row for one pipeline step
#'
#' Captures a uniform lineage record (decision 0005): input/output row & column
#' counts, rows dropped, key coverage, total NA cells, a schema hash, the
#' governing contract's pass/fail, timestamp, and git SHA. Row-bind the records
#' from every step into the pipeline's audit target.
#'
#' @param output The step's output data frame.
#' @param step Short step name (e.g. `"link_coaches"`).
#' @param stage Pipeline stage (`"ingest"`, `"clean"`, `"link"`, `"features"`,
#'   `"model"`, `"report"`).
#' @param input Optional input data frame, to compute deltas.
#' @param keys Optional character vector of key columns to summarize coverage on.
#' @param contract_passed Optional logical: did the step's data contract pass?
#'
#' @return A one-row tibble of audit fields.
#' @export
audit_step <- function(
  output,
  step,
  stage,
  input = NULL,
  keys = NULL,
  contract_passed = NA
) {
  n_keys_out <- if (!is.null(keys) && all(keys %in% names(output))) {
    dplyr::n_distinct(dplyr::select(output, dplyr::all_of(keys)))
  } else {
    NA_integer_
  }
  tibble::tibble(
    step = step,
    stage = stage,
    n_rows_in = if (is.null(input)) NA_integer_ else nrow(input),
    n_rows_out = nrow(output),
    rows_delta = if (is.null(input)) NA_integer_ else nrow(output) - nrow(input),
    n_cols_out = ncol(output),
    n_keys_out = n_keys_out,
    n_na_cells = sum(vapply(output, \(x) sum(is.na(x)), integer(1))),
    schema_hash = schema_hash(output),
    contract_passed = contract_passed,
    timestamp = Sys.time(),
    git_sha = current_git_sha()
  )
}
