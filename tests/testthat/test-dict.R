# The data dictionaries in inst/dict/*.yml must document exactly the columns of
# their cleaned target schema, with matching types, so the dictionaries never
# silently drift from the pipeline (decision 0005). Each cleaned target is
# deterministic given its raw parquet, so we reconstruct the schema via the
# clean_*() function rather than depending on a built _targets store. Skips when
# the raw data is unavailable (e.g. R CMD check without the data-latest release).

# dataset (dict file / `dataset` field) -> raw file + the function that produces
# the cleaned target schema (identity where the target is the raw read).
dict_schema_specs <- list(
  picks = list(file = "picks.parquet", clean = clean_picks),
  player_stats = list(
    file = "player_stats.parquet",
    clean = clean_player_stats
  ),
  coaches = list(file = "coaches.parquet", clean = clean_coaches),
  teams = list(file = "teams.parquet", clean = clean_teams),
  roster = list(file = "roster.parquet", clean = clean_roster),
  recruiting = list(file = "recruiting.parquet", clean = clean_recruiting),
  conference_tiers = list(file = "conference_tiers.parquet", clean = identity),
  nfl_draft_picks = list(
    file = "nfl_draft_picks.parquet",
    clean = clean_nfl_draft_picks
  ),
  nfl_rosters = list(file = "nfl_rosters.parquet", clean = clean_nfl_rosters),
  nfl_player_stats = list(
    file = "nfl_player_stats.parquet",
    clean = clean_nfl_player_stats
  )
)

# dict `type` token -> the R storage type (typeof) it must map to.
dict_type_to_typeof <- c(
  int32 = "integer",
  string = "character",
  double = "double",
  logical = "logical"
)

test_that("each inst/dict/*.yml documents exactly its cleaned target schema", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("yaml")

  data_dir <- test_path("..", "..", "data")
  skip_if_not(dir.exists(data_dir), "raw data/ not available")

  dict_dir <- system.file("dict", package = "cfbstats")
  skip_if(identical(dict_dir, ""), "installed dict/ not found")

  for (ds in names(dict_schema_specs)) {
    spec <- dict_schema_specs[[ds]]
    parquet <- file.path(data_dir, spec$file)
    skip_if_not(file.exists(parquet), paste0("missing ", spec$file))

    cleaned <- spec$clean(arrow::read_parquet(parquet))
    actual_type <- vapply(cleaned, typeof, character(1))

    dict <- yaml::read_yaml(file.path(dict_dir, paste0(ds, ".yml")))
    documented <- vapply(dict$columns, function(col) col$name, character(1))
    documented_type <- vapply(
      dict$columns,
      function(col) col$type,
      character(1)
    )
    names(documented_type) <- documented

    # Set equality both ways: no undocumented columns, no phantom entries.
    expect_setequal(documented, names(actual_type))

    # Types must match on the columns present in both (aligned by name).
    common <- intersect(documented, names(actual_type))
    expected <- unname(dict_type_to_typeof[documented_type[common]])
    got <- unname(actual_type[common])
    expect_equal(
      got,
      expected,
      info = paste0(ds, ": ", paste(common, collapse = ", "))
    )
  }
})
