"""@bruin
name: lakehouse.full_model_polars
type: python
image: python:3.12
connection: ducklake
enabled: false
description: |
  Optional Polars parity model for the SQL aggregate. It attaches the same
  DuckLake catalog from environment variables and returns a Polars DataFrame
  that Bruin materializes back into DuckLake when enabled.

depends:
  - lakehouse.incremental_model

materialization:
  type: table

columns:
  - name: crash_date
    type: DATE
    primary_key: true
  - name: zip_code
    type: VARCHAR
    primary_key: true
  - name: contributing_factor
    type: VARCHAR
    primary_key: true
  - name: vehicle_type
    type: VARCHAR
    primary_key: true
  - name: collision_count
    type: BIGINT
  - name: total_number_of_persons_injured
    type: BIGINT
  - name: total_number_of_persons_killed
    type: BIGINT
  - name: _lakehouse_loaded_at
    type: TIMESTAMP
@bruin"""

import os

import duckdb
import polars as pl


def _quote(value: str) -> str:
    return value.replace("'", "''")


def _connect_ducklake() -> duckdb.DuckDBPyConnection:
    conn = duckdb.connect()
    conn.execute("INSTALL ducklake")
    conn.execute("INSTALL postgres")
    conn.execute("INSTALL httpfs")
    conn.execute("LOAD ducklake")
    conn.execute("LOAD postgres")
    conn.execute("LOAD httpfs")
    conn.execute(
        f"""
        CREATE OR REPLACE SECRET r2_secret (
          TYPE S3,
          KEY_ID '{_quote(os.environ["AWS_ACCESS_KEY_ID"])}',
          SECRET '{_quote(os.environ["AWS_SECRET_ACCESS_KEY"])}',
          REGION '{_quote(os.environ.get("AWS_REGION", "auto"))}',
          ENDPOINT '{_quote(os.environ["R2_S3_ENDPOINT"])}',
          URL_STYLE 'path'
        )
        """
    )

    postgres_catalog = (
        "postgres:"
        f"dbname={os.environ['POSTGRES_DB']} "
        f"user={os.environ['POSTGRES_USER']} "
        f"password={os.environ['POSTGRES_PASSWORD']} "
        f"host={os.environ['POSTGRES_HOST']} "
        f"port={os.environ.get('POSTGRES_PORT', '5432')} "
        "sslmode=require"
    )
    conn.execute(
        f"""
        ATTACH 'ducklake:{_quote(postgres_catalog)}' AS ducklake
        (DATA_PATH '{_quote(os.environ["DUCKLAKE_DATA_PATH"])}')
        """
    )
    conn.execute("USE ducklake")
    return conn


def materialize() -> pl.DataFrame:
    conn = _connect_ducklake()
    source = conn.sql(
        """
        SELECT
          crash_date,
          zip_code,
          contributing_factor_vehicle_1,
          vehicle_type_code1,
          number_of_persons_injured,
          number_of_persons_killed
        FROM lakehouse.incremental_model
        """
    ).pl()

    return (
        source.group_by(
            [
                "crash_date",
                "zip_code",
                "contributing_factor_vehicle_1",
                "vehicle_type_code1",
            ]
        )
        .agg(
            pl.len().alias("collision_count"),
            pl.col("number_of_persons_injured")
            .fill_null(0)
            .sum()
            .alias("total_number_of_persons_injured"),
            pl.col("number_of_persons_killed")
            .fill_null(0)
            .sum()
            .alias("total_number_of_persons_killed"),
        )
        .rename(
            {
                "contributing_factor_vehicle_1": "contributing_factor",
                "vehicle_type_code1": "vehicle_type",
            }
        )
        .with_columns(pl.lit(os.environ["BRUIN_EXECUTION_DATETIME"]).str.to_datetime().alias("_lakehouse_loaded_at"))
        .select(
            [
                "crash_date",
                "zip_code",
                "contributing_factor",
                "vehicle_type",
                "collision_count",
                "total_number_of_persons_injured",
                "total_number_of_persons_killed",
                "_lakehouse_loaded_at",
            ]
        )
    )
