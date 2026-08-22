test_that("add_change_features derives transfer, direction, and coach changes", {
  ps <- tibble::tibble(
    playerId = c("1", "1", "2"),
    season = c(2020L, 2021L, 2021L),
    team = c("Boise State", "USC", "Alabama"),
    tier = c(2L, 3L, 3L),
    coach_id = c(10L, 20L, 30L)
  )
  out <- add_change_features(ps)

  # Player 1's second season: transferred up, coach changed, did not follow.
  row <- out[out$playerId == "1" & out$season == 2021L, ]
  expect_true(row$transferred)
  expect_equal(row$transfer_direction, "up")
  expect_true(row$hc_changed)
  expect_false(row$followed_coach)

  # First observed season has no prior: not a transfer.
  first <- out[out$playerId == "1" & out$season == 2020L, ]
  expect_false(first$transferred)
  expect_true(is.na(first$transfer_direction))
})

test_that("followed_coach is TRUE when a transfer keeps the same head coach", {
  ps <- tibble::tibble(
    playerId = c("3", "3"),
    season = c(2022L, 2023L),
    team = c("Washington State", "Miami"),
    tier = c(2L, 3L),
    coach_id = c(99L, 99L)
  )
  out <- add_change_features(ps)
  row <- out[out$season == 2023L, ]
  expect_true(row$transferred)
  expect_true(row$followed_coach)
})

test_that("add_roster_weight attaches roster weight by player-season", {
  ps <- tibble::tibble(
    playerId = c("1", "1", "2"),
    season = c(2020L, 2021L, 2021L)
  )
  roster <- tibble::tibble(
    playerId = c("1", "1"),
    season = c(2020L, 2021L),
    weight = c(210L, 225L)
  )
  out <- add_roster_weight(ps, roster)
  expect_equal(out$weight[out$playerId == "1" & out$season == 2021L], 225L)
  expect_true(is.na(out$weight[out$playerId == "2"]))
})
