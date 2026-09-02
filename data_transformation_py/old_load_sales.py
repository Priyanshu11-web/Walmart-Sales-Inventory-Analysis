import pandas as pd
import pyodbc
import time

# -----------------------------------
# 1. Settings
# -----------------------------------

CSV_FILE = r"D:\Inventory-intelligence\data\raw\sales_train_validation.csv"

SERVER = "MAGICBOOK"
DATABASE = "walmart_inventory"

CHUNK_SIZE = 250


# -----------------------------------
# 2. Connect to SQL Server
# -----------------------------------

connection = pyodbc.connect(
    "DRIVER={ODBC Driver 17 for SQL Server};"
    f"SERVER={SERVER};"
    f"DATABASE={DATABASE};"
    "Trusted_Connection=yes;"
)

cursor = connection.cursor()
cursor.fast_executemany = True

print("Connected to SQL Server!")


# -----------------------------------
# 3. Load calendar mapping
# -----------------------------------

calendar = pd.read_sql(
    "SELECT d, date FROM calendar",
    connection
)

calendar["date"] = pd.to_datetime(calendar["date"])

date_mapping = dict(
    zip(calendar["d"], calendar["date"])
)

print(f"Calendar mappings loaded: {len(date_mapping):,}")


# -----------------------------------
# 4. Process sales CSV in chunks
# -----------------------------------

start_time = time.time()
total_rows = 0

for chunk_number, df in enumerate(
    pd.read_csv(CSV_FILE, chunksize=CHUNK_SIZE),
    start=1
):

    # Find d_1, d_2, d_3 ... columns
    day_columns = [
        col for col in df.columns
        if col.startswith("d_")
    ]

    # Wide → Long
    long_df = df.melt(
        id_vars=[
            "id",
            "item_id",
            "dept_id",
            "cat_id",
            "store_id",
            "state_id"
        ],
        value_vars=day_columns,
        var_name="d",
        value_name="units_sold"
    )

    # d_1 → actual date
    long_df["sale_date"] = long_df["d"].map(date_mapping)

    # Keep required columns
    long_df = long_df[
        [
            "item_id",
            "dept_id",
            "cat_id",
            "store_id",
            "state_id",
            "sale_date",
            "units_sold"
        ]
    ]

    # Convert to Python tuples
    rows = list(
        long_df.itertuples(
            index=False,
            name=None
        )
    )

    # Insert into SQL Server
    cursor.executemany(
        """
        INSERT INTO sales_fact
        (
            item_id,
            dept_id,
            cat_id,
            store_id,
            state_id,
            sale_date,
            units_sold
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        rows
    )

    connection.commit()

    total_rows += len(rows)

    elapsed = time.time() - start_time

    print(
        f"Chunk {chunk_number:>3} | "
        f"Inserted {len(rows):,} | "
        f"Total {total_rows:,} | "
        f"Time {elapsed/60:.1f} min"
    )


# -----------------------------------
# 5. Close connection
# -----------------------------------

cursor.close()
connection.close()

elapsed = time.time() - start_time

print("\n===================================")
print("SALES DATA LOAD COMPLETED")
print("===================================")
print(f"Total rows inserted: {total_rows:,}")
print(f"Time taken: {elapsed/60:.2f} minutes")