# ODB-EnvSync

Tool to sync Oracle DB environments, reads db objects, outputs as json, and generates install scripts

## Generating install scripts

Use the procedure `oei_env_sync_capture_pkg.p_generate_install_script` to obtain the DDL needed to recreate objects captured in `ENV_SYNC_SCHEMA_OBJECTS`.

```
declare
    l_script clob;
begin
    oei_env_sync_capture_pkg.p_generate_install_script(
        in_schema_name  => 'MY_SCHEMA',
        in_compare_json => null,
        out_script      => l_script);

    dbms_output.put_line(l_script);
end;
/
```

- If `in_compare_json` is `NULL`, the procedure exports the installation script for every captured object in the schema.
- Provide a JSON array in `in_compare_json` with objects containing `schema_name`, `object_type`, and `object_name` (for example, the payload exported from another environment) to limit the script to objects that are **missing** from the uploaded snapshot. Objects found in the JSON are skipped so only the missing DDL is generated. A minimal payload looks like:

  ```
  [
    {"schema_name": "MY_SCHEMA", "object_type": "TABLE", "object_name": "EXISTING_TABLE"},
    {"schema_name": "MY_SCHEMA", "object_type": "VIEW", "object_name": "EXISTING_VIEW"}
  ]
  ```
- When every object in the capture is present in the uploaded JSON the procedure returns `NULL`, signalling that there is nothing left to install.

### Change detection via DDL hash

The capture process now stores a normalized DDL hash (`ddl_hash`, SHA‑256) for each object. During script generation, objects whose current database DDL hash equals the stored hash are considered unchanged and are skipped. This keeps the generated script focused on objects that actually changed since the last capture.

Notes:
- Hashing uses a normalized DDL (whitespace collapsed, terminators removed) for stability.
- If DDL cannot be retrieved for an object, it will be included by default.

### Installation order

The generated script already follows the order expected by a clean installation. When iterating over captured metadata the package applies an explicit sort key so statements are emitted in dependency-friendly batches:

1. Sequences
2. Tables
3. Indexes
4. Triggers
5. Views
6. Package specifications
7. Package bodies
8. Procedures
9. Functions

Within each group objects are ordered by name. This means structures required by later objects—such as tables referenced by indexes, triggers, or PL/SQL—are always installed first. The package relies on `DBMS_METADATA.GET_DDL`, so each statement includes its dependent metadata (for example, table-level constraints), allowing the script to run from top to bottom on a brand-new database without additional orchestration.

If you need a different ordering—for example to group related modules together—you can switch an object type to the `CUSTOM` strategy in `OEI_INSTALL_SCRIPT_STRATEGY` and point it to a hand-crafted script.

### DIFF support (minimal ALTERs)

When both source and target schemas exist in the same database, the tool attempts to generate ALTER statements using `DBMS_METADATA_DIFF` instead of full DDL, based on a per‑type strategy in `OEI_INSTALL_SCRIPT_TYPE_MODE`:

- Default modes: `TABLE` and `INDEX` use `DIFF`, others use `DDL`.
- You can change modes by updating `OEI_INSTALL_SCRIPT_TYPE_MODE`.
- In APEX “Generate Install Script”, provide a compare JSON where `schema_name` for each row identifies the target schema to compare against. The generator will:
  - Emit ALTER statements for objects present in the target when changed.
  - Emit full CREATE statements for objects missing at the target.
  - Skip objects when hashes indicate no change.

Notes:
- `DBMS_METADATA_DIFF` may not support every structure; the generator falls back to full DDL when a DIFF isn’t available or returns empty.
- When your target is in a different database, `DIFF` is not possible; the generator uses full DDL.

## Database objects

The project now includes a configuration table responsible for defining how installation scripts are produced:

- `INSTALL_SCRIPT_STRATEGY`: permite escolher entre gerar automaticamente os scripts a partir dos DDLs dos objectos (`generation_mode = 'DDL'`) ou apontar um script customizado, complementado pela configuracao de prefixos e sufixos por tipo de objecto (`generation_mode = 'CUSTOM'`).

Os DDLs estao agora organizados por tipo de artefacto em `sql/ddl` e os modulos PL/SQL encontram-se em `sql/modules`. O ficheiro [`sql/ddl/install_script_strategy/oei_install_script_strategy.sql`](sql/ddl/install_script_strategy/oei_install_script_strategy.sql) contem o DDL completo para criar as tabelas, comentarios e trigger de auditoria que garante o preenchimento consistente das colunas de data. A tabela `INSTALL_SCRIPT_STRATEGY_NAMING` permite definir prefixos e sufixos especificos por tipo de objecto (por exemplo `SEQUENCE` com prefixo `SEQ_`), garantindo a flexibilidade necessaria para estrategias `CUSTOM`.
## Installation (SQL Developer)

- Run the main installer from the project root:

  @install_all.sql

  This installs core objects (tables + package) and then installs the APEX 24.2 pages. You will be prompted (or set at the top of the script) for `WORKSPACE` and `APP_ID` to target the right APEX application.

- If you want to install only the core DB pieces, run the first part manually and skip the APEX installer:

  @sql/ddl/install_script_strategy/oei_install_script_strategy.sql
  @sql/ddl/install_script_strategy/oei_install_script_type_mode.sql
  @sql/ddl/env_sync_capture/oei_env_sync_schema_objects.sql
  @sql/ddl/env_sync_capture/oei_env_sync_snapshots.sql
  @sql/ddl/env_sync_capture/oei_env_sync_releases.sql
  @sql/ddl/env_sync_capture/oei_env_sync_install_log.sql
  @sql/ddl/env_sync_capture/oei_env_sync_audit.sql
  @sql/ddl/env_sync_capture/oei_env_sync_scheduler.sql
  @sql/modules/env_sync_capture/oei_sync_capture_pkg.pks
  @sql/modules/env_sync_capture/oei_sync_capture_pkg.pkb

### Governance & Safety (optional but recommended in DEV)
- DDL audit (DEV only): `oei_env_sync_audit` table + schema-level DDL trigger captures who/what/when and the DDL text. Enable/disable helpers are provided:
  - `exec oei_env_sync_audit_enable;`
  - `exec oei_env_sync_audit_disable;`
- Nightly capture job: `OEI_ENV_SYNC_CAPTURE_JOB` scans `oei_env_sync_capture_targets` and runs `p_capture_schema` at 02:00 daily. Populate targets:
  - `insert into oei_env_sync_capture_targets(schema_name) values ('MY_SCHEMA'); commit;`
- APEX authorization schemes (when APEX installer is enabled): two schemes are created — "Can Capture" and "Can Release" — driven by DB roles `OEI_ENV_CAPTURE_ROLE` and `OEI_ENV_RELEASE_ROLE`. Assign these schemes to pages or buttons as desired.
