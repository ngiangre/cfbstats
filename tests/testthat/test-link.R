test_that("link_drafted never adds rows when an id maps to multiple picks", {
  # CFBD reuses collegeAthleteId across eras; picks carries history back to
  # 1936, so one player-season id can match two picks (decision 0011).
  ps <- tibble::tibble(
    playerId = c("1", "1", "2"),
    season = c(2020L, 2021L, 2021L),
    team = c("Georgia", "Georgia", "Alabama")
  )
  picks <- tibble::tibble(
    playerId = c("1", "1", "2"),
    year = c(1972L, 2022L, 2023L),
    round = c(1L, 3L, 2L),
    overall = c(5L, 90L, 40L)
  )
  out <- link_drafted(ps, picks)
  # Strictly 1:1 on the backbone — no fan-out.
  expect_equal(nrow(out), nrow(ps))
})

test_that("link_drafted resolves a colliding id to the in-window pick", {
  ps <- tibble::tibble(playerId = "1", season = 2021L, team = "Georgia")
  picks <- tibble::tibble(
    playerId = c("1", "1"),
    year = c(1972L, 2022L),
    round = c(1L, 3L),
    overall = c(5L, 90L)
  )
  out <- link_drafted(ps, picks)
  expect_equal(out$draft_year, 2022L)
  expect_true(out$drafted)
})

test_that("link_drafted marks undrafted player-seasons and completes drafted", {
  ps <- tibble::tibble(
    playerId = c("1", "3"),
    season = c(2021L, 2021L),
    team = c("Georgia", "Troy")
  )
  picks <- tibble::tibble(
    playerId = "1",
    year = 2022L,
    round = 3L,
    overall = 90L
  )
  out <- link_drafted(ps, picks)
  expect_false(any(is.na(out$drafted)))
  expect_true(out$drafted[out$playerId == "1"])
  expect_false(out$drafted[out$playerId == "3"])
})
