list.of.packages <- c(
  "data.table","tidycensus", "tidyverse","dotenv"
)
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
suppressPackageStartupMessages(lapply(list.of.packages, require, character.only=T))

# Set your working directory
setwd("C:/git/Peer-States-Ranking/")

# Load Census API Key
load_dot_env()
api_key = Sys.getenv("CENSUS_API_KEY")
census_api_key(api_key)

# Define variables of interest
variables = c(
  median_household_income = "B19019_001",
  
  total_pop = "B01001_001",
  male_under5_pop = "B01001_003",
  male_5to9_pop = "B01001_004",
  male_10to14_pop = "B01001_005",
  female_under5_pop = "B01001_027",
  female_5to9_pop = "B01001_028",
  female_10to14_pop = "B01001_029",

  children_under6_pop = "B23008_002",
  under6_twoparents_inlaborforce = "B23008_004",
  under6_oneparentfather_inlaborforce = "B23008_010",
  under6_oneparentmother_inlaborforce = "B23008_013",
  
  laborforce_denominator = "B23025_001",
  laborforce_pop = "B23025_002"
)

# Download and cache
if(!file.exists("input/acs_cache.RData")){
  acs_long = get_acs(
    geography = "state",
    variables = variables,
    year = 2024,
    survey = "acs1"
  )
  save(acs_long, file="input/acs_cache.RData")
}else{
  load("input/acs_cache.RData")
}

# Pivot wide and calculate joint indicators
acs_wide <- acs_long %>%
  select(GEOID, NAME, variable, estimate) %>%
  pivot_wider(
    names_from = variable,
    values_from = estimate
  ) %>%
  mutate(
    children_under15_pop = male_under5_pop + male_5to9_pop + male_10to14_pop +
      female_under5_pop + female_5to9_pop + female_10to14_pop,
    
    children_under15_pct = (children_under15_pop / total_pop),
    
    children_under6_pct = (children_under6_pop / total_pop),
    
    children_under6_caregivers_inlaborforce_pop = under6_twoparents_inlaborforce +
      under6_oneparentfather_inlaborforce +
      under6_oneparentmother_inlaborforce,
    
    children_under6_caregivers_inlaborforce_pct = (children_under6_caregivers_inlaborforce_pop / children_under6_pop),
    
    laborforce_pct = (laborforce_pop / laborforce_denominator)
  ) %>%
  select(
    GEOID,
    NAME,
    median_household_income,
    children_under6_pop,
    children_under6_pct,
    children_under15_pop,
    children_under15_pct,
    children_under6_caregivers_inlaborforce_pop,
    children_under6_caregivers_inlaborforce_pct,
    laborforce_pop,
    laborforce_pct,
    total_pop
  )

# Isolate Maryland's data to use for comparison
maryland_data <- acs_wide %>%
  filter(NAME == "Maryland")

# Define the indicator columns to perform calculations on
indicator_cols <- names(acs_wide)[!names(acs_wide) %in% c("GEOID", "NAME")]

# Calculate absolute difference and rank for each indicator
acs_ranked <- acs_wide %>%
  mutate(
    # Create new columns for the absolute difference from Maryland for each indicator
    across(
      .cols = all_of(indicator_cols),
      .fns = ~ abs(.x - maryland_data[[cur_column()]]),
      .names = "{.col}_diff_md"
    )
  ) %>%
  mutate(
    # Create new columns for the rank of the difference
    across(
      .cols = ends_with("_diff_md"),
      .fns = ~ rank(.x, ties.method = "min"),
      .names = "{.col}_rank"
    )
  )

# Create a matrix of just the indicator columns for scaling
indicator_matrix <- acs_wide %>%
  select(all_of(indicator_cols)) %>%
  as.matrix()

# Apply the scale() function
scaled_indicator_matrix <- scale(indicator_matrix)

# Find the row index for Maryland to get its scaled data vector
md_index <- which(acs_wide$NAME == "Maryland")
maryland_scaled_vector <- scaled_indicator_matrix[md_index, ]

# Cosine similarity function
cosine_similarity <- function(v1, v2) {
  sum(v1 * v2, na.rm = TRUE) / (sqrt(sum(v1^2, na.rm = TRUE)) * sqrt(sum(v2^2, na.rm = TRUE)))
}

# Apply the function to every row of the scaled matrix, comparing it to Maryland's vector
cosine_similarities <- apply(scaled_indicator_matrix, 1, function(row) {
  cosine_similarity(row, maryland_scaled_vector)
})

# Add the calculated similarities and the joint rank to the main dataframe
acs_final <- acs_ranked %>%
  mutate(cosine_sim_md = cosine_similarities) %>%
  mutate(
    # Rank by descending similarity score (most similar gets rank 1)
    joint_rank_md = rank(desc(cosine_sim_md), ties.method = "min")
  )

final_col_order <- c(
  "GEOID", "NAME",
  unlist(lapply(indicator_cols, function(col_name) {
    c(col_name, paste0(col_name, "_diff_md"), paste0(col_name, "_diff_md_rank"))
  })),
  "cosine_sim_md", "joint_rank_md"
)

acs_final <- acs_final %>%
  select(any_of(final_col_order))

fwrite(acs_final, "output/peer_rankings.csv")