test_that("build_duckdb bundles named tables into a queryable database", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb")

  tables <- list(
    picks = data.frame(playerId = c("1", "2"), drafted = c(TRUE, TRUE)),
    roster = data.frame(playerId = c("1", "3"), season = c(2015L, 2016L))
  )
  db <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db), add = TRUE)

  expect_equal(build_duckdb(tables, db), db)
  expect_true(file.exists(db))

  con <- DBI::dbConnect(duckdb::duckdb(), db, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  expect_setequal(DBI::dbListTables(con), c("picks", "roster"))
  expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM picks")$n, 2L)
  # The database is queryable across tables on the shared player key.
  joined <- DBI::dbGetQuery(
    con,
    "SELECT r.season FROM roster r JOIN picks p ON r.playerId = p.playerId"
  )
  expect_equal(joined$season, 2015L)
})

test_that("build_duckdb rejects an unnamed table list", {
  skip_if_not_installed("duckdb")
  db <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db), add = TRUE)
  expect_error(build_duckdb(list(data.frame(x = 1)), db), "named")
})

test_that("build_duckdb rebuilds from scratch, dropping stale tables", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb")

  db <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db), add = TRUE)
  build_duckdb(list(old = data.frame(x = 1L)), db)
  build_duckdb(list(new = data.frame(y = 2L)), db)

  con <- DBI::dbConnect(duckdb::duckdb(), db, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  expect_setequal(DBI::dbListTables(con), "new")
})
