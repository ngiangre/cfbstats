# NFL outcomes via nflverse (decision 0014). clean_nfl_* standardize the pulled
# tables; link_nfl_draft bridges CFBD picks to nflverse ids by draft slot behind
# a name guard (the same collision defense as recruiting, decision 0013).

test_that("clean_nfl_player_stats aggregates weekly REG to one row per player-season", {
  raw <- tibble::tibble(
    player_id = c("00-1", "00-1", "00-1", "00-2"),
    player_display_name = c("A Back", "A Back", "A Back", "B End"),
    season = c(2020L, 2020L, 2020L, 2020L),
    week = c(1L, 2L, 1L, 1L),
    season_type = c("REG", "REG", "POST", "REG"),
    completions = c(0L, 0L, 0L, 0L),
    attempts = c(0L, 0L, 0L, 0L),
    passing_yards = c(0L, 0L, 0L, 0L),
    passing_tds = c(0L, 0L, 0L, 0L),
    passing_interceptions = c(0L, 0L, 0L, 0L),
    carries = c(10L, 12L, 5L, 0L),
    rushing_yards = c(40L, 60L, 25L, 0L),
    rushing_tds = c(1L, 0L, 1L, 0L),
    targets = c(0L, 0L, 0L, 0L),
    receptions = c(0L, 0L, 0L, 0L),
    receiving_yards = c(0L, 0L, 0L, 0L),
    receiving_tds = c(0L, 0L, 0L, 0L),
    def_tackles_solo = c(0L, 0L, 0L, 3L),
    def_sacks = c(0, 0, 0, 1.5),
    def_interceptions = c(0L, 0L, 0L, 0L)
  )

  out <- clean_nfl_player_stats(raw)

  # One row per player-season; POST week excluded.
  expect_equal(nrow(out), 2L)
  a <- out[out$gsis_id == "00-1", ]
  # 2 REG weeks -> games == 2; regular-season rushing summed (POST dropped).
  expect_equal(a$games, 2L)
  expect_equal(a$rush_atts, 22L)
  expect_equal(a$rush_yards, 100L)

  # Types match the dictionary contract.
  expect_type(out$gsis_id, "character")
  expect_type(out$games, "integer")
  expect_type(out$def_sacks, "double")
})

test_that("clean_nfl_rosters drops idless rows and keys one row per player-season", {
  raw <- tibble::tibble(
    gsis_id = c("00-1", "00-1", NA_character_),
    season = c(2019L, 2020L, 2019L),
    team = c("BUF", "BUF", "NYJ"),
    position = c("QB", "QB", "WR"),
    status = c("ACT", "ACT", "ACT"),
    years_exp = c(0L, 1L, 3L),
    height = c(73, 73, 71),
    weight = c(215L, 218L, 190L),
    college = c("Wyoming", "Wyoming", "State"),
    rookie_year = c(2019L, 2019L, NA_integer_)
  )

  out <- clean_nfl_rosters(raw)

  expect_equal(nrow(out), 2L)
  expect_setequal(out$season, c(2019L, 2020L))
  expect_true(all(!is.na(out$gsis_id)))
})

test_that("link_nfl_draft bridges by slot and name-guards wrong matches", {
  picks <- tibble::tibble(
    playerId = c("1", "2", "3", "4"),
    name = c("Will Anderson Jr.", "Real Player", "Old Timer", "Wrong Person"),
    year = c(2023L, 2021L, 1999L, 2022L),
    round = c(1L, 1L, 1L, 2L),
    overall = c(3L, 10L, 1L, 40L)
  )
  nfl <- tibble::tibble(
    season = c(2023L, 2021L, 2022L),
    round = c(1L, 1L, 2L),
    pick = c(3L, 10L, 40L),
    gsis_id = c("g-anderson", "g-real", "g-someoneelse"),
    pfr_player_id = c("p-anderson", "p-real", "p-else"),
    pfr_player_name = c("Will Anderson", "Real Player", "Different Guy"),
    to = c(2025L, 2024L, 2024L),
    games = c(40L, 60L, 30L),
    seasons_started = c(3L, 4L, 2L)
  )

  out <- link_nfl_draft(picks, nfl)

  # Row count preserved.
  expect_equal(nrow(out), nrow(picks))

  # Suffix-only difference passes the guard.
  anderson <- out[out$playerId == "1", ]
  expect_true(anderson$nfl_matched)
  expect_equal(anderson$gsis_id, "g-anderson")
  expect_equal(anderson$nfl_games, 40L)

  # Exact name match.
  expect_true(out$nfl_matched[out$playerId == "2"])

  # Pre-window pick: no slot in nflverse -> unmatched.
  old <- out[out$playerId == "3", ]
  expect_false(old$nfl_matched)
  expect_true(is.na(old$gsis_id))

  # Slot matches but names disagree (wrong person): ids nulled.
  wrong <- out[out$playerId == "4", ]
  expect_false(wrong$nfl_matched)
  expect_true(is.na(wrong$gsis_id))
  expect_true(is.na(wrong$nfl_games))
})
