# Peer-States-Ranking

Repository for ranking U.S. states as peers based on measured demographic and economic characteristics.

## Setup

1. **Clone the repository** and navigate to its directory.

2. **Install R and required packages**  
   Ensure you have R installed. The script will automatically install any missing R packages.

3. **Configure your Census API key**  
   - Copy `.env-example` to `.env`:
     ```
     cp .env-example .env
     ```
   - Open `.env` and add your [U.S. Census API key](https://api.census.gov/data/key_signup.html) in place of `your-us-census-api-key-here`.

## Usage

Run the main script from the `code` directory:
```R
source("code/find_peers.R")
```
This will download the latest ACS data (if not already cached), process it, and output peer rankings to `output/peer_rankings.csv`.

## What does `find_peers.R` do?

- Loads U.S. Census ACS 1-year data for all states using selected demographic and economic variables.
- Calculates indicators such as:
  - Median household income
  - Percent of children under 6 and under 15
  - Labor force participation rates for caregivers
- Compares each state to Maryland:
  - Computes absolute differences for each indicator
  - Ranks states by similarity to Maryland for each indicator
  - Calculates an overall similarity score using cosine similarity across all indicators
- Outputs a ranked list of peer states to `output/peer_rankings.csv`, including all calculated metrics and similarity ranks.
