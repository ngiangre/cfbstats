test_that("conference_tier_levels is an ordered 3-tier scale", {
  lv <- conference_tier_levels()
  expect_equal(unname(lv), c(1L, 2L, 3L))
  expect_equal(names(lv), c("FCS and below", "Group of 5", "Power"))
})

test_that("contract_conference_tiers passes a well-formed lookup and its coverage", {
  skip_if_not_installed("pointblank")
  tiers <- tibble::tibble(
    season = c(2015L, 2015L),
    conference = c("SEC", "Sun Belt"),
    tier = c(3L, 2L),
    tier_label = c("Power", "Group of 5")
  )
  stats <- tibble::tibble(season = 2015L, conference = c("SEC", "Sun Belt"))
  agents <- contract_conference_tiers(tiers, stats, stop_on_fail = FALSE)
  expect_true(pointblank::all_passed(agents$lookup))
  expect_true(pointblank::all_passed(agents$coverage))
})

test_that("contract_conference_tiers flags an unmapped conference", {
  skip_if_not_installed("pointblank")
  tiers <- tibble::tibble(
    season = 2015L,
    conference = "SEC",
    tier = 3L,
    tier_label = "Power"
  )
  stats <- tibble::tibble(season = 2015L, conference = c("SEC", "MAC"))
  agents <- contract_conference_tiers(tiers, stats, stop_on_fail = FALSE)
  expect_false(pointblank::all_passed(agents$coverage))
})
