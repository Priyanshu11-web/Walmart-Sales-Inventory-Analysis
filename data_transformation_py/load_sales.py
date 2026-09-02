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
# 4. Get already-loaded combinations
# -----------------------------------

existing = pd.read_sql(
    """
    SELECT DISTINCT item_id, store_id
    FROM dbo.sales_fact
    """,
    connection
)

existing_combinations = set(
    zip(existing["item_id"], existing["store_id"])
)

print(
    f"Existing item-store combinations: "
    f"{len(existing_combinations):,}"
)

print(
    f"Remaining combinations: "
    f"{30490 - len(existing_combinations):,}"
)


# -----------------------------------
# 5. Process CSV in chunks
# -----------------------------------

start_time = time.time()
total_rows = 0
skipped_combinations = 0

for chunk_number, df in enumerate(
    pd.read_csv(CSV_FILE, chunksize=CHUNK_SIZE),
    start=1
):

    # -----------------------------------
    # Skip item-store combinations
    # already present in SQL Server
    # -----------------------------------

    mask = [
        (item_id, store_id) not in existing_combinations
        for item_id, store_id
        in zip(df["item_id"], df["store_id"])
    ]

    new_df = df[mask]

    skipped = len(df) - len(new_df)
    skipped_combinations += skipped

    if new_df.empty:
        print(
            f"Chunk {chunk_number:>3} | "
            f"All {len(df)} combinations already loaded | "
            f"Skipping"
        )
        continue

    # -----------------------------------
    # Find d_1, d_2, d_3 ... columns
    # -----------------------------------

    day_columns = [
        col for col in new_df.columns
        if col.startswith("d_")
    ]

    # -----------------------------------
    # Wide → Long
    # -----------------------------------

    long_df = new_df.melt(
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

    # -----------------------------------
    # d_1 → actual date
    # -----------------------------------

    long_df["sale_date"] = long_df["d"].map(date_mapping)

    # -----------------------------------
    # Keep required columns
    # -----------------------------------

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

    # -----------------------------------
    # Convert to Python tuples
    # -----------------------------------

    rows = list(
        long_df.itertuples(
            index=False,
            name=None
        )
    )

    # -----------------------------------
    # Insert
    # -----------------------------------

    cursor.executemany(
        """
        INSERT INTO dbo.sales_fact
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

    # Add newly inserted combinations
    # to the set so they won't be inserted again
    for item_id, store_id in zip(
        new_df["item_id"],
        new_df["store_id"]
    ):
        existing_combinations.add(
            (item_id, store_id)
        )

    elapsed = time.time() - start_time

    print(
        f"Chunk {chunk_number:>3} | "
        f"Inserted {len(rows):,} | "
        f"Total new rows {total_rows:,} | "
        f"Time {elapsed/60:.1f} min"
    )


# -----------------------------------
# 6. Close connection
# -----------------------------------

cursor.close()
connection.close()

elapsed = time.time() - start_time

print("\n===================================")
print("SALES DATA RESUME COMPLETED")
print("===================================")
print(f"New rows inserted: {total_rows:,}")
print(f"Time taken: {elapsed/60:.2f} minutes")