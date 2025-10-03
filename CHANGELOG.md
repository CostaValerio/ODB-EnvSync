# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2025-10-03

- Package renamed to `oei_env_sync_capture_pkg` with p_/f_ prefixes.
- Added comments and documentation throughout the spec/body.
- APEX 24.2 pages (readable + installer): Capture Schema, Capture Object, Generate Install Script, Captured Objects Report, Upload Snapshot, Changes Review, Create Release, Promotion History.
- Main installer `install_all.sql` (APEX install commented by default) and `uninstall_all.sql`.
- Milestone 1: DDL normalization and hashing; store `ddl_hash`; skip unchanged in generation.
- Milestone 2: DIFF support using `DBMS_METADATA_DIFF` with per-type mode table; fallbacks to full DDL.
- Milestone 3: Snapshots table; change listing API; APEX review pages.
- Milestone 4: Releases and install log tables; script headers/footers; optional recompile step; APEX pages.
- Milestone 5: Governance — DDL audit trigger, nightly capture scheduler, role-based APEX auth schemes.
- Milestone 6: Coverage expansion — directories, types, materialized views, jobs; dependent DDL; seed data MERGE generation.

### Notes
- Materialized view logs support is pending and will be addressed in a future release.
- File names for the package are being aligned; the installer still references `oei_sync_capture_pkg.*` for now.

