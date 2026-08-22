# Build the season x conference -> tier lookup (decision 0003).
#
# Tier is an ordinal competitive level used to measure transfer *direction*:
#   3 = Power, 2 = Group of 5 / other FBS, 1 = FCS and below. Higher = stronger.
#
# The lookup is season-aware: conference names/memberships shift over 2010-2025
# (Pac-12 collapse, Big East -> AAC, WAC dropping FBS football). We build from
# the (season, conference) pairs actually present in player_stats so any new
# conference in a data refresh defaults to tier 1 rather than silently dropping.

library(dplyr)
library(arrow)

# Load the package for conference_tier_levels() (the single source of truth for
# the tier labels) and the fail-fast data contract.
pkgload::load_all(quiet = TRUE)

tier_levels <- conference_tier_levels()

power <- c("ACC", "SEC", "Big Ten", "Big 12", "Pac-12", "Pac-10", "Big East")
g5 <- c(
  "American Athletic",
  "Mountain West",
  "Mid-American",
  "Sun Belt",
  "Conference USA",
  "FBS Independents",
  "Western Athletic"
)

observed <- read_parquet("data/player_stats.parquet", as_data_frame = FALSE) |>
  distinct(season, conference) |>
  collect()

conference_tiers <- observed |>
  mutate(
    tier = case_when(
      conference %in% power ~ 3L,
      conference %in% g5 ~ 2L,
      .default = 1L
    ),
    # Pac-12 collapses to two teams (Oregon State, Washington State) in
    # 2024-2025 -> treat as no longer a Power conference.
    tier = if_else(conference == "Pac-12" & season >= 2024, 2L, tier),
    # Western Athletic dropped FBS football after 2012 -> FCS thereafter.
    tier = if_else(conference == "Western Athletic" & season >= 2013, 1L, tier),
    tier_label = recode_values(
      tier,
      from = unname(tier_levels),
      to = names(tier_levels),
      unmatched = "error"
    )
  ) |>
  arrange(season, desc(tier), conference)

# NOTE: "FBS Independents" is tier 2 here, but Notre Dame is Power-level. Because
# this lookup is conference-level, apply a Notre Dame team-level override in the
# transfer-direction feature step, not here.

write_parquet(conference_tiers, "data/conference_tiers.parquet")

# Fail-fast data contract (decision 0003). Uses the current player_stats as the
# coverage universe, so a stale lookup against refreshed data fails here.
contract_conference_tiers(conference_tiers, observed)
