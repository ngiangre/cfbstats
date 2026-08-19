# Save NFL draft pick data
httr2::request(
  "https://api.collegefootballdata.com/draft/picks"
) |>
  httr2::req_headers(
    Authorization = paste("Bearer", Sys.getenv("CFBD_API_KEY"))
  ) |>
  httr2::req_perform() |>
  httr2::resp_body_json(
    simplifyVector = TRUE
  ) |>
  tibble::tibble() |>
  tidyr::unnest(
    cols = hometownInfo,
    names_sep = "_"
  ) |>
  arrow::write_parquet(
    "data/picks.parquet"
  )

years <-
  seq(2010, 2025, 1) |>
  as.integer()

# Save player statistics from each season
purrr::walk(
  years,
  ~ {
    tryCatch(
      {
        httr2::request(
          "https://api.collegefootballdata.com/stats/player/season"
        ) |>
          httr2::req_url_query(
            year = .x
          ) |>
          httr2::req_headers(
            Authorization = paste("Bearer", Sys.getenv("CFBD_API_KEY"))
          ) |>
          httr2::req_perform() |>
          httr2::resp_body_json(simplifyVector = TRUE) |>
          tibble::tibble() |>
          arrow::write_parquet(
            paste0("data/player_", .x, "_stats.parquet")
          )
      },
      finally = function(e) e$message
    )
  }
)

purrr::map(
  years,
  ~ {
    arrow::read_parquet(
      paste0("data/player_", .x, "_stats.parquet"),
      as_data_frame = FALSE
    ) |>
      dplyr::collect()
  }
) |>
  purrr::list_rbind() |>
  arrow::write_parquet(
    'data/player_stats.parquet'
  )

# Coaches data
httr2::request(
  "https://api.collegefootballdata.com/coaches"
) |>
  httr2::req_headers(
    Authorization = paste("Bearer", Sys.getenv("CFBD_API_KEY"))
  ) |>
  httr2::req_perform() |>
  httr2::resp_body_json(
    simplifyVector = TRUE
  ) |>
  tibble::tibble() |>
  tidyr::unnest(
    cols = seasons,
    names_sep = "_"
  ) |>
  arrow::write_parquet(
    "data/coaches.parquet"
  )

arrow::read_parquet(
  "data/coaches.parquet",
  col_select = c("id", "firstName", "lastName")
) |>
  dplyr::distinct()

players <-
  arrow::read_parquet(
    'data/player_stats.parquet',
    as_data_frame = FALSE
  ) |>
  dplyr::pull(
    player,
    as_vector = TRUE
  ) |>
  unique() |>
  sort()

picked <-
  arrow::read_parquet(
    "data/picks.parquet",
    as_data_frame = FALSE
  ) |>
  dplyr::pull(
    name,
    as_vector = TRUE
  ) |>
  unique()

intersect(
  players,
  picked
) |>
  dplyr::n_distinct()

teams <-
  arrow::read_parquet(
    'data/player_stats.parquet',
    as_data_frame = FALSE
  ) |>
  dplyr::pull(
    team,
    as_vector = TRUE
  ) |>
  unique() |>
  sort()

teams_of_picked <-
  arrow::read_parquet(
    "data/picks.parquet",
    as_data_frame = FALSE
  ) |>
  dplyr::pull(
    collegeTeam,
    as_vector = TRUE
  ) |>
  unique() |>
  sort()

coaches <-
  arrow::read_parquet(
    "data/coaches.parquet",
    as_data_frame = FALSE
  ) |>
  dplyr::distinct(
    firstName,
    lastName,
    seasons_school,
    seasons_year
  ) |>
  dplyr::collect()

teams_of_coaches <-
  arrow::read_parquet(
    "data/coaches.parquet",
    as_data_frame = FALSE
  ) |>
  dplyr::pull(
    seasons_school,
    as_vector = TRUE
  ) |>
  unique() |>
  sort()

intersect(
  teams_of_picked,
  teams
) |>
  dplyr::n_distinct()

intersect(
  teams_of_coaches,
  teams
) |>
  dplyr::n_distinct()
