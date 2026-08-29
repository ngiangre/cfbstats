# resolve_nfl_outcome() is the general college->NFL bridge: drafted via slot,
# undrafted via a name guard, and — crucially — refuses to guess on an
# ambiguous name collision (no false attribution).

roster_cols <- function(...) {
  tibble::tibble(...)
}

test_that("a drafted player resolves via the draft slot", {
  subject <- tibble::tibble(
    playerId = "10",
    player = "Cam Ward",
    college = "Miami",
    last_college_season = 2024L
  )
  picks_nfl <- tibble::tibble(
    playerId = "10",
    year = 2025L,
    round = 1L,
    overall = 1L,
    gsis_id = "00-1"
  )
  rosters <- roster_cols(
    gsis_id = "00-1",
    player_name = "Cam Ward",
    season = 2025L,
    college = "Miami",
    rookie_year = 2025L
  )
  stats <- tibble::tibble(gsis_id = "00-1", games = 17L)

  out <- resolve_nfl_outcome(subject, picks_nfl, rosters, stats)
  expect_equal(out$nfl_status, "drafted")
  expect_equal(out$nfl_match_method, "slot")
  expect_equal(out$draft_overall, 1L)
  expect_equal(out$nfl_seasons, 1L)
})

test_that("an undrafted player resolves via a name match", {
  subject <- tibble::tibble(
    playerId = "20",
    player = "Kyle Allen",
    college = "Texas A&M",
    last_college_season = 2017L
  )
  picks_nfl <- tibble::tibble(
    playerId = character(),
    year = integer(),
    round = integer(),
    overall = integer(),
    gsis_id = character()
  )
  rosters <- roster_cols(
    gsis_id = rep("00-2", 3),
    player_name = rep("Kyle Allen", 3),
    season = c(2018L, 2019L, 2020L),
    college = rep("Houston", 3),
    rookie_year = rep(2018L, 3)
  )
  stats <- tibble::tibble(gsis_id = "00-2", games = 13L)

  out <- resolve_nfl_outcome(subject, picks_nfl, rosters, stats)
  expect_equal(out$nfl_status, "undrafted-signed")
  expect_equal(out$nfl_match_method, "name")
  expect_equal(out$nfl_seasons, 3L)
})

test_that("an ambiguous name collision is NOT linked", {
  subject <- tibble::tibble(
    playerId = "30",
    player = "John Smith",
    college = NA_character_,
    last_college_season = NA_integer_
  )
  picks_nfl <- tibble::tibble(
    playerId = character(),
    year = integer(),
    round = integer(),
    overall = integer(),
    gsis_id = character()
  )
  rosters <- roster_cols(
    gsis_id = c("00-a", "00-b"),
    player_name = c("John Smith", "John Smith"),
    season = c(2015L, 2016L),
    college = c("Alabama", "Ohio State"),
    rookie_year = c(2015L, 2016L)
  )
  stats <- tibble::tibble(gsis_id = character(), games = integer())

  out <- resolve_nfl_outcome(subject, picks_nfl, rosters, stats)
  expect_equal(out$nfl_status, "no-NFL-record")
  expect_equal(out$nfl_match_method, "none")
})

test_that("a name collision resolves when college disambiguates", {
  subject <- tibble::tibble(
    playerId = "40",
    player = "John Smith",
    college = "Alabama",
    last_college_season = 2014L
  )
  picks_nfl <- tibble::tibble(
    playerId = character(),
    year = integer(),
    round = integer(),
    overall = integer(),
    gsis_id = character()
  )
  rosters <- roster_cols(
    gsis_id = c("00-a", "00-b"),
    player_name = c("John Smith", "John Smith"),
    season = c(2015L, 2016L),
    college = c("Alabama", "Ohio State"),
    rookie_year = c(2015L, 2016L)
  )
  stats <- tibble::tibble(gsis_id = c("00-a", "00-b"), games = c(5L, 9L))

  out <- resolve_nfl_outcome(subject, picks_nfl, rosters, stats)
  expect_equal(out$nfl_status, "undrafted-signed")
  expect_equal(out$nfl_match_method, "name+college")
  expect_equal(out$gsis_id, "00-a")
})
