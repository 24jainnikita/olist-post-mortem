"""
build/run_query.py
==================
Run any SQL file against data/olist.duckdb and print the result as a
formatted table to stdout. Also writes output to exports/<sql_filename>.txt.

For 04_seller_ranking.sql specifically, also writes exports/04_seller_ranking.csv
because the result is large and intended for further processing.

Usage:
    python build/run_query.py sql/01_monthly_revenue.sql
    python build/run_query.py sql/04_seller_ranking.sql   # also writes CSV

The script executes every semicolon-separated statement in the file.
Only the last statement that returns rows is printed (matches the
pattern of files that end with a SELECT after setup CTEs).
"""

import csv
import sys
from pathlib import Path

try:
    import duckdb
except ImportError:
    sys.exit("ERROR: duckdb not installed. Run: pip install duckdb")

ROOT    = Path(__file__).resolve().parent.parent
DB_PATH = ROOT / "data" / "olist.duckdb"
EXPORTS = ROOT / "exports"

# ---------------------------------------------------------------------------

def fmt_val(v) -> str:
    """Format a single cell value for display."""
    if v is None:
        return "NULL"
    if isinstance(v, float):
        return f"{v:,.3f}"
    if isinstance(v, int):
        return f"{v:,}"
    return str(v)


def print_table(cols: list[str], rows: list[tuple], title: str = "") -> str:
    """
    Render a result set as a plain-text table.
    Returns the rendered string (also prints it).
    """
    str_rows = [[fmt_val(v) for v in row] for row in rows]
    widths   = [max(len(c), max((len(r[i]) for r in str_rows), default=0))
                for i, c in enumerate(cols)]

    sep  = "+-" + "-+-".join("-" * w for w in widths) + "-+"
    hdr  = "| " + " | ".join(c.ljust(widths[i]) for i, c in enumerate(cols)) + " |"

    lines = []
    if title:
        lines.append(f"\n{'='*len(sep)}")
        lines.append(f"  {title}")
        lines.append(f"{'='*len(sep)}")
    lines.append(sep)
    lines.append(hdr)
    lines.append(sep)
    for row in str_rows:
        lines.append("| " + " | ".join(v.ljust(widths[i]) for i, v in enumerate(row)) + " |")
    lines.append(sep)
    lines.append(f"  {len(rows)} row{'s' if len(rows) != 1 else ''}")

    output = "\n".join(lines)
    print(output, flush=True)
    return output


def run_sql_file(sql_path: Path) -> None:
    if not sql_path.exists():
        sys.exit(f"ERROR: file not found: {sql_path}")
    if not DB_PATH.exists():
        sys.exit(f"ERROR: database not found at {DB_PATH}\n"
                 f"       Run: python build/load_data.py")

    sql = sql_path.read_text(encoding="utf-8")

    con = duckdb.connect(str(DB_PATH), read_only=True)

    output_parts = [f"File: {sql_path}", f"DB:   {DB_PATH}"]

    try:
        # execute() on a multi-statement string runs all statements and
        # returns the result of the last one. For files with CTEs + a final
        # SELECT this is exactly what we want.
        rel = con.execute(sql)
        if rel is None:
            print("Query executed — no rows returned.")
            con.close()
            return

        cols = [d[0] for d in rel.description]
        rows = rel.fetchall()
        rendered = print_table(cols, rows, title=sql_path.name)
        output_parts.append(rendered)

    except duckdb.Error as e:
        msg = f"\nERROR executing {sql_path.name}:\n  {e}"
        print(msg)
        output_parts.append(msg)
    finally:
        con.close()

    # Write to exports/
    EXPORTS.mkdir(exist_ok=True)
    out_file = EXPORTS / (sql_path.stem + ".txt")
    out_file.write_text("\n".join(output_parts), encoding="utf-8")
    print(f"\n  Output also written to {out_file.relative_to(ROOT)}")

    # For query 04, also write a CSV so the large result is usable
    if sql_path.stem == "04_seller_ranking":
        csv_file = EXPORTS / "04_seller_ranking.csv"
        with open(csv_file, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(cols)
            for row in rows:
                writer.writerow(["" if v is None else v for v in row])
        print(f"  CSV also written to {csv_file.relative_to(ROOT)}")


# ---------------------------------------------------------------------------

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(
            "Usage: python build/run_query.py <path/to/query.sql>\n"
            "Example: python build/run_query.py sql/01_monthly_revenue.sql"
        )
    run_sql_file(Path(sys.argv[1]))
