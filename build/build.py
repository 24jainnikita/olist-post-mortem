import sys
import json
import csv
import subprocess
from pathlib import Path

try:
    import duckdb
except ImportError:
    sys.exit("ERROR: duckdb not installed. Run: pip install duckdb")

ROOT = Path(__file__).resolve().parent.parent
DB_PATH = ROOT / "data" / "olist.duckdb"
SQL_DIR = ROOT / "sql"
EXPORTS_DIR = ROOT / "exports"
WEB_DATA_DIR = ROOT / "web" / "src" / "data"

def run_step(cmd, name):
    print(f"Running {name}...")
    res = subprocess.run(cmd, cwd=str(ROOT))
    if res.returncode != 0:
        print(f"ERROR: {name} failed.")
        sys.exit(1)

def main():
    # 1. Load data and run sanity checks
    run_step([sys.executable, "build/load_data.py"], "load_data.py")
    run_step([sys.executable, "tests/sanity_checks.py"], "sanity_checks.py")
    
    EXPORTS_DIR.mkdir(parents=True, exist_ok=True)
    WEB_DATA_DIR.mkdir(parents=True, exist_ok=True)
    
    con = duckdb.connect(str(DB_PATH), read_only=True)
    
    import datetime
    
    class DateTimeEncoder(json.JSONEncoder):
        def default(self, obj):
            if isinstance(obj, (datetime.date, datetime.datetime)):
                return obj.isoformat()
            return super().default(obj)
            
    # 2 & 3. Run all SQL queries and save to JSON and CSV
    sql_files = sorted(SQL_DIR.glob("*.sql"))
    for sql_file in sql_files:
        print(f"Running {sql_file.name}...")
        sql = sql_file.read_text(encoding="utf-8")
        try:
            rel = con.execute(sql)
            if not rel:
                continue
            cols = [d[0] for d in rel.description]
            rows = rel.fetchall()
            
            # Write JSON
            json_path = WEB_DATA_DIR / f"{sql_file.stem}.json"
            dict_rows = [dict(zip(cols, row)) for row in rows]
            with open(json_path, "w", encoding="utf-8") as f:
                json.dump(dict_rows, f, indent=2, cls=DateTimeEncoder)
                
            # Write CSV
            csv_path = EXPORTS_DIR / f"{sql_file.stem}.csv"
            with open(csv_path, "w", newline="", encoding="utf-8") as f:
                writer = csv.writer(f)
                writer.writerow(cols)
                writer.writerows(rows)
        except Exception as e:
            print(f"Error running {sql_file.name}: {e}")
            sys.exit(1)
            
    # 4. Generate summary.json
    print("Generating summary.json...")
    
    # Total revenue
    revenue = con.execute("""
        SELECT SUM(oi.price) 
        FROM order_items oi 
        JOIN orders o ON o.order_id = oi.order_id 
        WHERE o.order_status = 'delivered'
    """).fetchone()[0]
    
    # Overall bad review rate
    bad_reviews_pct = con.execute("""
        WITH reviews_deduped AS (
            SELECT DISTINCT ON (order_id) order_id, review_score
            FROM order_reviews
            ORDER BY order_id, review_answer_timestamp DESC, review_id DESC
        )
        SELECT 100.0 * SUM(CASE WHEN r.review_score IN (1,2) THEN 1 ELSE 0 END) / COUNT(r.review_score)
        FROM orders o
        JOIN reviews_deduped r ON r.order_id = o.order_id
        WHERE o.order_status = 'delivered'
    """).fetchone()[0]
    
    row08 = con.execute(open(SQL_DIR / '08_excess_bad_reviews.sql', encoding="utf-8").read()).fetchone()
    late_order_count = row08[0]
    ontime_order_count = row08[1]
    total_orders = late_order_count + ontime_order_count
    
    late_delivery_rate = 100.0 * late_order_count / total_orders
    
    late_with_review = con.execute("""
        WITH reviews_deduped AS (
            SELECT DISTINCT ON (order_id) order_id, review_score
            FROM order_reviews
            ORDER BY order_id, review_answer_timestamp DESC, review_id DESC
        )
        SELECT SUM(CASE WHEN r.review_score IS NOT NULL THEN 1 ELSE 0 END)
        FROM orders o
        JOIN reviews_deduped r ON r.order_id = o.order_id
        WHERE o.order_status = 'delivered' 
        AND o.order_delivered_customer_date IS NOT NULL 
        AND o.order_estimated_delivery_date IS NOT NULL
        AND o.order_delivered_customer_date > o.order_estimated_delivery_date
    """).fetchone()[0]
    
    late_bad_review_rate = 100.0 * row08[2] / late_with_review
    ontime_bad_review_rate = row08[4]
    
    late_7 = con.execute("""
        WITH reviews_deduped AS (
            SELECT DISTINCT ON (order_id) order_id, review_score
            FROM order_reviews
            ORDER BY order_id, review_answer_timestamp DESC, review_id DESC
        )
        SELECT 
            100.0 * SUM(CASE WHEN r.review_score IN (1,2) THEN 1 ELSE 0 END) / COUNT(r.review_score)
        FROM orders o
        JOIN reviews_deduped r ON r.order_id = o.order_id
        WHERE o.order_status = 'delivered' 
        AND o.order_delivered_customer_date IS NOT NULL 
        AND o.order_estimated_delivery_date IS NOT NULL
        AND CAST((epoch(o.order_delivered_customer_date) - epoch(o.order_estimated_delivery_date)) / 86400.0 AS DOUBLE) >= 7
    """).fetchone()[0]
    
    repeat_rate = con.execute("""
        WITH first_purchase AS (
            SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) as order_count
            FROM orders o
            JOIN customers c ON c.customer_id = o.customer_id
            WHERE o.order_status = 'delivered'
            GROUP BY c.customer_unique_id
        )
        SELECT 100.0 * SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) / COUNT(*)
        FROM first_purchase
    """).fetchone()[0]
    
    summary = {
        "total_delivered_orders": total_orders,
        "total_revenue": revenue,
        "overall_bad_review_rate": bad_reviews_pct,
        "late_delivery_rate": late_delivery_rate,
        "late_bad_review_rate": late_bad_review_rate,
        "ontime_bad_review_rate": ontime_bad_review_rate,
        "seven_plus_days_late_bad_review_rate": late_7,
        "excess_bad_reviews": row08[6],
        "excess_as_pct_of_all_bad": row08[8],
        "repeat_purchase_rate": repeat_rate
    }
    
    with open(WEB_DATA_DIR / "summary.json", "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)
        
    # 5. Generate threshold.json
    print("Generating threshold.json...")
    thresholds = []
    for t in range(16):
        row = con.execute(f"""
            WITH reviews_deduped AS (
                SELECT DISTINCT ON (order_id) order_id, review_score
                FROM order_reviews
                ORDER BY order_id, review_answer_timestamp DESC, review_id DESC
            ),
            base AS (
                SELECT 
                    CAST((epoch(o.order_delivered_customer_date) - epoch(o.order_estimated_delivery_date)) / 86400.0 AS DOUBLE) as delay_days,
                    r.review_score
                FROM orders o
                JOIN reviews_deduped r ON r.order_id = o.order_id
                WHERE o.order_status = 'delivered' 
                AND o.order_delivered_customer_date IS NOT NULL 
                AND o.order_estimated_delivery_date IS NOT NULL
                AND r.review_score IS NOT NULL
            )
            SELECT
                (SELECT COUNT(*) FROM base WHERE delay_days > {t}) * 100.0 / (SELECT COUNT(*) FROM base) as share_exceeding,
                (SELECT AVG(review_score) FROM base WHERE delay_days > {t}) as avg_score_above,
                (SELECT AVG(review_score) FROM base WHERE delay_days <= {t}) as avg_score_below
        """).fetchone()
        
        thresholds.append({
            "threshold_days": t,
            "share_exceeding_pct": row[0],
            "avg_score_above": row[1],
            "avg_score_below": row[2]
        })
        
    with open(WEB_DATA_DIR / "threshold.json", "w", encoding="utf-8") as f:
        json.dump(thresholds, f, indent=2)
        
    con.close()
    print("Build complete.")

if __name__ == "__main__":
    main()
