# ODB-EnvSync — Improvements Checklist

Use this checklist to plan and track the next iterations. Check off items as they are delivered. Grouped by milestones to enable incremental value.

## Milestone 1 — Baseline Capture Quality
- [x] Add `f_normalize_ddl(in_ddl clob) return clob` to remove noise (whitespace, terminators, storage, schema qualifiers).
- [x] Add `f_ddl_hash(in_ddl clob) return varchar2` using `STANDARD_HASH` (e.g., SHA256).
- [x] Alter `OEI_ENV_SYNC_SCHEMA_OBJECTS` to include `ddl_hash` (nullable) and index on `(schema_name, object_type, object_name)` if missing.
- [x] Persist `ddl_hash` during capture (`p_capture_object`, `p_capture_schema`).
- [x] In `p_generate_install_script`, skip unchanged objects by comparing stored hash vs current DDL hash.
- [ ] Smoke test on sample objects (sequence, table, view, package, procedure, function, trigger, index).
- [x] Update documentation to explain hashing behavior and its impact.

## Milestone 2 — Smart Diff & Minimal Changes
- [x] Implement `f_diff_object(in_src_schema, in_tgt_schema, in_type, in_name) return clob` using `DBMS_METADATA_DIFF` where supported.
- [x] Table diffs: try `ALTER` statements; fallback to full DDL when complex/unsupported.
- [x] Index diffs: attempt DIFF; fallback to full DDL.
- [x] Code units (package/proc/func/trigger/view): keep `CREATE OR REPLACE` behavior.
- [x] Add a strategy switch per type (e.g., DDL vs DIFF) controlled by config table.
- [ ] Error handling and feature detection for `DBMS_METADATA_DIFF` (improve detection vs generic exception).
- [x] Documentation updates for DIFF behavior and configuration.

## Milestone 3 — Snapshots & Change Review (APEX)
- [ ] Create `OEI_ENV_SYNC_SNAPSHOTS` to store uploaded JSON snapshots with metadata (who/when/target schema/source env).
- [ ] Add APEX page: Upload Snapshot (store JSON; validate format).
- [ ] Add `f_list_changes(in_schema, in_compare_json) return clob` → JSON array of changes with `change_type` (ADDED/MODIFIED/MISSING/DROPPED) and details.
- [ ] Add APEX page: Changes Review with filters, include/exclude toggles, and DDL preview using above APIs.

## Milestone 4 — Releases, Promotion & Audit
- [ ] Create `OEI_ENV_SYNC_RELEASES` (id, created_by, created_on, status, manifest_json, script_clob, hash).
- [ ] Create `OEI_ENV_SYNC_INSTALL_LOG` (release_id, target_schema, installed_by, installed_on, success, log_clob).
- [ ] APEX page: Create Release (generate manifest + script; mark status Draft/Approved/Released).
- [ ] APEX page: Promotion History with drill‑down to logs and script hashes.
- [ ] Enhance generated script headers/footers: `set define off`, `whenever sqlerror exit failure`, `alter session set current_schema = ...`.
- [ ] Optional recompile step: `UTL_RECOMP.RECOMP_SERIAL(schema => ...)` and invalids report.

## Milestone 5 — Governance & Safety
- [ ] DEV‑only DDL trigger `OEI_ENV_SYNC_AUDIT` to capture who/what/when of ad‑hoc changes.
- [ ] Nightly scheduler job to run `p_capture_schema` for selected schemas.
- [ ] APEX authorization scheme/roles for capture vs release actions.

## Milestone 6 — Coverage Expansion
- [ ] Add support: materialized views/logs, directories, types, scheduler jobs.
- [ ] Include dependent DDL via `DBMS_METADATA.GET_DEPENDENT_DDL` (grants, synonyms).
- [ ] Config data seeds: mark tables and generate `MERGE` DML for deltas.

## Milestone 7 — Consistency & Packaging
- [ ] Align file names with package name (optionally rename to `oei_env_sync_capture_pkg.pks/pkb`).
- [ ] One‑shot installer scripts (objects + APEX 24.2 pages) and uninstall script.
- [ ] Update READMEs (root and `sql/apex/`) with new workflow and APEX screenshots.
- [ ] Semantic versioning + CHANGELOG.md; tag first release.

## Milestone 8 — Quality & CI (optional)
- [ ] Add unit tests with utPLSQL (where available) for normalization/hash and diff logic.
- [ ] Linting/formatting guidance for PL/SQL and SQL scripts.
- [ ] Example datasets and demo app bundle for onboarding.
