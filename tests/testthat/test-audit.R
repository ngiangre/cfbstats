test_that("schema_hash is stable to row changes but sensitive to schema changes", {
  a <- tibble::tibble(x = 1:3, y = letters[1:3])
  b <- tibble::tibble(x = 1:10, y = letters[1:10])
  expect_equal(schema_hash(a), schema_hash(b))

  d <- tibble::tibble(x = 1:3, z = letters[1:3])
  expect_false(identical(schema_hash(a), schema_hash(d)))
})

test_that("audit_step records deltas and key coverage", {
  input <- tibble::tibble(id = c("1", "1", "2"), v = 1:3)
  output <- dplyr::distinct(input, id)
  rec <- audit_step(output, "dedup", "clean", input = input, keys = "id")
  expect_equal(rec$n_rows_in, 3L)
  expect_equal(rec$n_rows_out, 2L)
  expect_equal(rec$rows_delta, -1L)
  expect_equal(rec$n_keys_out, 2L)
  expect_true(is.na(rec$contract_passed))
})
