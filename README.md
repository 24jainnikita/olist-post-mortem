# Olist Post-Mortem

An analysis of the Olist Brazilian e-commerce dataset to identify the core drivers of bad reviews and prioritize solutions.

## Live Demo
[View the Interactive Post-Mortem Web App](https://24jainnikita.github.io/olist-post-mortem/)

## Key Findings
- **Delivery Delays Wreck Customer Experience**: The bad-review rate jumps from 9.22% for on-time orders to 54.07% for late orders (a 5.9x lift).
- **Extreme Delays**: For orders that are 7 or more days late, the bad review rate skyrockets to 78.4%.
- **Excess Bad Reviews**: We attribute an upper bound of 3,436 excess bad reviews directly to lateness (representing 28.0% of all bad reviews).
- **Customer Churn**: The overall repeat purchase rate stands at a critical 3.0%, underscoring the long-term cost of bad experiences.

## Data Integrity
All figures in this analysis are computationally verified against the raw dataset using DuckDB. The build pipeline runs strict sanity checks (`tests/sanity_checks.py`) on every rebuild to ensure total order counts, cohort sizes, and revenue metrics tie out correctly with zero duplicate counting. During validation, a critical date-truncation bug caused by standard `date_diff('day', ...)` functions was identified and resolved by shifting to exact sub-second precision (`epoch` timestamp math), ensuring delay aggregations match strict timestamp comparisons.

## Limitations
- **Delivered Orders Only**: This analysis specifically isolates orders with a `delivered` status. Canceled or permanently lost orders are excluded.
- **Observational Data**: The findings are correlational. While lateness strongly predicts bad reviews, we cannot definitively claim 100% causal isolation.
- **Confounding Variables**: Category difficulty (e.g., shipping heavy furniture), region remoteness, and intrinsic seller quality are all heavily entangled with lateness and were not completely isolated.
- **Revenue Scope**: Revenue metrics track item price only and exclude freight costs.

## How to rebuild

To regenerate all data and outputs from scratch, follow these steps:

1. **Download the Dataset**: Download the [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) from Kaggle. Extract all `.csv` files into the `data/` directory (these files are gitignored).
2. Run the build script, which will:
   - Load the raw CSVs into a fresh local DuckDB database (`data/olist.duckdb`).
   - Run sanity checks to ensure data integrity.
   - Execute all SQL analysis queries (`sql/*.sql`).
   - Export the query results to `web/src/data/*.json` (for the web application) and `exports/*.csv` (for further analysis).
   - Generate `summary.json` and `threshold.json` containing top-level KPIs.

```bash
python build/build.py
```

### Requirements

- Python 3.8+ (relies on standard library modules: `sys`, `json`, `csv`, `subprocess`, `pathlib`, `datetime`)
- DuckDB (`pip install duckdb`)
