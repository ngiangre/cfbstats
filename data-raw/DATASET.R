resp_picks <- httr2::request(
  "https://api.collegefootballdata.com/draft/picks"
) |>
  httr2::req_headers(
    Authorization = paste("Bearer", Sys.getenv("CFBD_API_KEY"))
  ) |>
  httr2::req_perform()

picks <-
  httr2::resp_body_json(resp_picks, simplifyVector = TRUE) |>
  tibble::tibble() |>
  tidyr::unnest(
    cols = hometownInfo,
    names_sep = "_"
  )

picks |>
  arrow::write_parquet(
    "data/picks.parquet"
  )
