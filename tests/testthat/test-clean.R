test_that("clean_picks coerces the athlete id to a string key and flags drafted", {
  raw <- tibble::tibble(
    collegeAthleteId = c(101L, NA_integer_),
    year = c(2015L, 2016L)
  )
  out <- clean_picks(raw)
  expect_type(out$playerId, "character")
  expect_equal(out$playerId, c("101", NA_character_))
  expect_true(all(out$drafted))
})

test_that("clean_coaches builds a tidy head-coach-season schema", {
  raw <- tibble::tibble(
    id = 7L,
    firstName = "Nick",
    lastName = "Saban",
    seasons_school = "Alabama",
    seasons_conference = "SEC",
    seasons_year = 2015L,
    seasons_games = 15L,
    seasons_wins = 14L,
    seasons_losses = 1L,
    seasons_srs = 20,
    seasons_spOverall = 30,
    seasons_spOffense = 25,
    seasons_spDefense = 5
  )
  out <- clean_coaches(raw)
  expect_equal(out$coach_name, "Nick Saban")
  expect_equal(out$school, "Alabama")
  expect_type(out$season, "integer")
  expect_true(all(c("srs", "sp_offense", "sp_defense") %in% names(out)))
})

test_that("clean_roster keys on a string playerId", {
  # Post-ingest roster: season is stamped from the query year; the endpoint's
  # own `year` (eligibility class) has been renamed to class_year.
  raw <- tibble::tibble(
    id = 55L,
    season = 2018L,
    class_year = 3L,
    team = "USC",
    position = "QB",
    height = 74L,
    weight = 220L,
    homeState = "CA"
  )
  out <- clean_roster(raw)
  expect_equal(out$playerId, "55")
  expect_type(out$season, "integer")
  expect_equal(out$season, 2018L)
  expect_true("weight" %in% names(out))
})
