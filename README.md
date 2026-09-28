# Olist Post-Mortem

An analysis of the Olist Brazilian e-commerce dataset to identify the core drivers of bad reviews and prioritize solutions.

## How to rebuild

To regenerate all data and outputs from scratch, run the build script. This script will:
1. Load the raw CSVs into a fresh local DuckDB database (`data/olist.duckdb`).
2. Run sanity checks to ensure data integrity.
3. Execute all SQL analysis queries (`sql/*.sql`).
4. Export the query results to `web/src/data/*.json` (for the web application) and `exports/*.csv` (for further analysis).
5. Generate `summary.json` and `threshold.json` containing top-level KPIs.

```bash
python build/build.py
```

### Requirements

- Python 3.8+
- DuckDB (`pip install duckdb`)
