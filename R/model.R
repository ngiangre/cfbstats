# Modeling stage (placeholder). Wired into the pipeline (decision 0004) so the
# DAG is complete end-to-end, but no real model is fit yet — v1 modeling (Breiman
# two-cultures; out-of-time evaluation) is a later, deliberate piece of work.

#' Placeholder draft model
#'
#' A stand-in for the modeling stage: records the shape of the modeling table so
#' the pipeline runs end-to-end and the report/site have something to display.
#' Replace with the real explanatory + predictive models (VISION §6).
#'
#' @param model_table The feature table (draft-eligible player-seasons).
#'
#' @return A small `cfb_model_stub` summarizing the modeling input.
#' @export
fit_draft_model <- function(model_table) {
  cli::cli_inform(
    "Model stage is a placeholder (decision 0004); no model is fit yet."
  )
  structure(
    list(
      n_rows = nrow(model_table),
      n_features = ncol(model_table),
      features = names(model_table),
      draft_rate = mean(model_table$drafted, na.rm = TRUE)
    ),
    class = "cfb_model_stub"
  )
}
