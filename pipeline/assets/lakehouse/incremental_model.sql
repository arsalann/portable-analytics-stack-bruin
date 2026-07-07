/* @bruin
name: lakehouse.incremental_model
type: duckdb.sql
connection: ducklake
description: |
  Incremental collision fact table. Daily runs refresh the requested date
  window plus a configurable lookback to catch late-arriving Socrata changes.

depends:
  - lakehouse.base_model

materialization:
  type: table
  strategy: delete+insert
  incremental_key: crash_date

columns:
  - name: collision_id
    type: BIGINT
    description: Unique collision identifier.
    primary_key: true
    checks:
      - name: unique
      - name: not_null
  - name: crash_date
    type: DATE
    description: Occurrence date of collision.
    checks:
      - name: not_null
  - name: _lakehouse_loaded_at
    type: TIMESTAMP
    description: Timestamp when Bruin loaded this row.

custom_checks:
  - name: incremental table has rows
    query: SELECT COUNT(*) > 0 FROM lakehouse.incremental_model
    value: 1

@bruin */

SELECT
  collision_id,
  crash_date,
  borough,
  zip_code,
  number_of_persons_injured,
  number_of_persons_killed,
  contributing_factor_vehicle_1,
  vehicle_type_code1,
  CURRENT_TIMESTAMP AS _lakehouse_loaded_at
FROM lakehouse.base_model
WHERE crash_date BETWEEN
  CAST('{{ start_date }}' AS DATE) - INTERVAL '{{ var.incremental_lookback_days }} days'
  AND CAST('{{ end_date }}' AS DATE)
