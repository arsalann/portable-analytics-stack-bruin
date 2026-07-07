/* @bruin
name: lakehouse.full_model
type: duckdb.sql
connection: ducklake
description: |
  Daily aggregate of collisions by date, ZIP code, contributing factor, and
  vehicle type.

depends:
  - lakehouse.incremental_model

materialization:
  type: table

columns:
  - name: crash_date
    type: DATE
    description: Occurrence date of collision.
    primary_key: true
    checks:
      - name: not_null
  - name: zip_code
    type: VARCHAR
    description: Postal code of incident occurrence.
    primary_key: true
  - name: contributing_factor
    type: VARCHAR
    description: Primary contributing factor.
    primary_key: true
  - name: vehicle_type
    type: VARCHAR
    description: Primary vehicle type.
    primary_key: true
  - name: collision_count
    type: BIGINT
    description: Total number of collisions.
    checks:
      - name: positive
  - name: total_number_of_persons_injured
    type: BIGINT
    description: Total number of persons injured.
    checks:
      - name: non_negative
  - name: total_number_of_persons_killed
    type: BIGINT
    description: Total number of persons killed.
    checks:
      - name: non_negative
  - name: _lakehouse_loaded_at
    type: TIMESTAMP
    description: Timestamp when Bruin loaded this row.

custom_checks:
  - name: aggregate grain is unique
    query: |
      SELECT COUNT(*)
      FROM (
        SELECT
          crash_date,
          COALESCE(zip_code, ''),
          COALESCE(contributing_factor, ''),
          COALESCE(vehicle_type, '')
        FROM lakehouse.full_model
        GROUP BY ALL
        HAVING COUNT(*) > 1
      )
    value: 0
  - name: aggregate table has rows
    query: SELECT COUNT(*) > 0 FROM lakehouse.full_model
    value: 1

@bruin */

SELECT
  crash_date,
  zip_code,
  contributing_factor_vehicle_1 AS contributing_factor,
  vehicle_type_code1 AS vehicle_type,
  COUNT(*) AS collision_count,
  SUM(COALESCE(number_of_persons_injured, 0)) AS total_number_of_persons_injured,
  SUM(COALESCE(number_of_persons_killed, 0)) AS total_number_of_persons_killed,
  CURRENT_TIMESTAMP AS _lakehouse_loaded_at
FROM lakehouse.incremental_model
GROUP BY
  crash_date,
  zip_code,
  contributing_factor_vehicle_1,
  vehicle_type_code1
