# Column names referenced via data-masking (dplyr) and pointblank::vars() read
# to R CMD check as undefined globals. Declare them to quiet the NOTE.
utils::globalVariables(c(
  "season",
  "conference",
  "tier",
  "tier_label",
  "has_tier"
))
