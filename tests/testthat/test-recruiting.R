# clean_recruiting() standardizes to a per-athlete rating table; link_recruiting()
# attaches ratings only when names agree (the id-collision guard, decision 0013).

test_that("clean_recruiting drops unlinkable recruits and dedupes to one per athlete", {
  raw <- tibble::tibble(
    athleteId = c("100", "100", "200", NA_character_),
    name = c("Jane Back", "Jane Back", "Sam Line", "No Id"),
    year = c(2019L, 2019L, 2020L, 2019L),
    stars = c(4L, 5L, 3L, 5L),
    rating = c(0.90, 0.95, 0.84, 0.99),
    ranking = c(50L, 40L, 300L, 1L),
    position = c("RB", "RB", "OL", "QB"),
    committedTo = c("A", "A", "B", "C")
  )

  out <- clean_recruiting(raw)

  # NA athleteId dropped; one row per athlete.
  expect_setequal(out$playerId, c("100", "200"))
  expect_equal(nrow(out), 2L)

  # Kept the higher-rated of athlete 100's two records.
  expect_equal(out$rating[out$playerId == "100"], 0.95)
  expect_equal(out$stars[out$playerId == "100"], 5L)

  # Types match the dictionary contract.
  expect_type(out$playerId, "character")
  expect_type(out$stars, "integer")
  expect_type(out$rating, "double")
  expect_type(out$national_rank, "integer")
})

test_that("normalize_name ignores punctuation, case, and generational suffixes", {
  expect_equal(normalize_name("T.J. Yeldon"), normalize_name("tj yeldon"))
  expect_equal(normalize_name("Devin Bush Jr."), normalize_name("Devin Bush"))
  expect_equal(normalize_name("D'Andre  Christmas"), "dandre christmas")
})

test_that("link_recruiting guards against wrong-person id collisions", {
  player_season <- tibble::tibble(
    playerId = c("1", "2", "3"),
    player = c("Cam Ward", "John Smith", "Unrated Walkon"),
    season = c(2024L, 2021L, 2022L),
    team = c("Miami", "State", "Tech")
  )
  recruiting <- tibble::tibble(
    playerId = c("1", "2"),
    recruit_name = c("Xavier Ward", "John Smith"),
    hs_class = c(2021L, 2018L),
    stars = c(3L, 4L),
    rating = c(0.866, 0.92),
    national_rank = c(773L, 120L),
    recruit_position = c("QB", "WR"),
    committed_to = c("Washington State", "State")
  )

  out <- link_recruiting(player_season, recruiting)

  # No row inflation.
  expect_equal(nrow(out), nrow(player_season))

  # Collision (Cam Ward <- Xavier Ward): rejected, ratings nulled.
  cam <- out[out$playerId == "1", ]
  expect_false(cam$recruit_matched)
  expect_true(is.na(cam$hs_rating))
  expect_true(is.na(cam$hs_stars))

  # True match: rating attached.
  smith <- out[out$playerId == "2", ]
  expect_true(smith$recruit_matched)
  expect_equal(smith$hs_rating, 0.92)
  expect_equal(smith$hs_stars, 4L)

  # No recruiting row at all: unmatched, nulled.
  walk <- out[out$playerId == "3", ]
  expect_false(walk$recruit_matched)
  expect_true(is.na(walk$hs_rating))
})
