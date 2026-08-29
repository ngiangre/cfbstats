# The stat-phase taxonomy makes the long player_stats interpretable. Guard its
# shape, the phase-ambiguous fumbles split, and the coverage contract.

test_that("stat_taxonomy() has valid, distinct, fully-populated rows", {
  tax <- stat_taxonomy()
  expect_setequal(
    names(tax),
    c("category", "statType", "phase", "label", "kind", "description")
  )
  expect_true(all(tax$phase %in% c("offense", "defense", "special_teams")))
  expect_true(all(tax$kind %in% c("scoring", "volume", "rate")))
  expect_false(anyNA(tax[c("category", "statType", "phase", "label", "kind")]))
  # No duplicate (category, statType) pairs.
  expect_equal(
    nrow(tax),
    nrow(dplyr::distinct(tax, .data$category, .data$statType))
  )
})

test_that("fumbles are split by statType, not lumped into one phase", {
  tax <- stat_taxonomy()
  fum <- tax[tax$category == "fumbles", ]
  expect_equal(fum$phase[fum$statType == "FUM"], "offense")
  expect_equal(fum$phase[fum$statType == "LOST"], "offense")
  expect_equal(fum$phase[fum$statType == "REC"], "defense")
})

test_that("label_stats() disambiguates a bare TD by phase", {
  stats <- tibble::tibble(
    playerId = c("1", "1"),
    category = c("passing", "defensive"),
    statType = c("TD", "TD"),
    stat = c("20", "2")
  )
  out <- label_stats(stats)
  expect_equal(out$phase, c("offense", "defense"))
  expect_equal(out$label, c("Passing touchdowns", "Defensive touchdowns"))
  expect_equal(nrow(out), nrow(stats))
})

test_that("contract_stat_taxonomy coverage passes when all pairs are mapped", {
  skip_if_not_installed("pointblank")
  ps <- tibble::tibble(
    category = c("passing", "rushing", "defensive"),
    statType = c("TD", "YDS", "SACKS")
  )
  agents <- contract_stat_taxonomy(ps, stop_on_fail = FALSE)
  expect_true(pointblank::all_passed(agents$lookup))
  expect_true(pointblank::all_passed(agents$coverage))
})

test_that("contract_stat_taxonomy coverage fails on an unmapped pair", {
  skip_if_not_installed("pointblank")
  ps <- tibble::tibble(
    category = c("passing", "newphase"),
    statType = c("TD", "MYSTERY")
  )
  agents <- contract_stat_taxonomy(ps, stop_on_fail = FALSE)
  expect_false(pointblank::all_passed(agents$coverage))
})
