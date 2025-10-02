# ODB-EnvSync

Tool to sync Oracle DB environments, reads db objects, outputs as json, and generates install scripts

## Generating install scripts

Use the procedure `env_sync_capture_pkg.p_generate_install_script` to obtain the DDL needed to recreate objects captured in `ENV_SYNC_SCHEMA_OBJECTS`.

```
declare
    l_script clob;
begin
    env_sync_capture_pkg.p_generate_install_script(
        p_schema_name => 'MY_SCHEMA',
        p_compare_json => null,
        p_script => l_script);

    dbms_output.put_line(l_script);
end;
/
```

- If `p_compare_json` is `NULL`, the procedure exports the installation script for every captured object in the schema.
- Provide a JSON array in `p_compare_json` with objects containing `schema_name`, `object_type`, and `object_name` (for example, the payload exported from another environment) to limit the script to objects that are **missing** from the uploaded snapshot. Objects found in the JSON are skipped so only the missing DDL is generated. A minimal payload looks like:

  ```
  [
    {"schema_name": "MY_SCHEMA", "object_type": "TABLE", "object_name": "EXISTING_TABLE"},
    {"schema_name": "MY_SCHEMA", "object_type": "VIEW", "object_name": "EXISTING_VIEW"}
  ]
  ```
- When every object in the capture is present in the uploaded JSON the procedure returns `NULL`, signalling that there is nothing left to install.

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

## Database objects

The project now includes a configuration table responsible for defining how installation scripts are produced:

- `INSTALL_SCRIPT_STRATEGY`: permite escolher entre gerar automaticamente os scripts a partir dos DDLs dos objectos (`generation_mode = 'DDL'`) ou apontar um script customizado, complementado pela configuracao de prefixos e sufixos por tipo de objecto (`generation_mode = 'CUSTOM'`).

Os DDLs estao agora organizados por tipo de artefacto em `sql/ddl` e os modulos PL/SQL encontram-se em `sql/modules`. O ficheiro [`sql/ddl/install_script_strategy/oei_install_script_strategy.sql`](sql/ddl/install_script_strategy/oei_install_script_strategy.sql) contem o DDL completo para criar as tabelas, comentarios e trigger de auditoria que garante o preenchimento consistente das colunas de data. A tabela `INSTALL_SCRIPT_STRATEGY_NAMING` permite definir prefixos e sufixos especificos por tipo de objecto (por exemplo `SEQUENCE` com prefixo `SEQ_`), garantindo a flexibilidade necessaria para estrategias `CUSTOM`.
