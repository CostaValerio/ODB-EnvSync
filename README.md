# ODB-EnvSync

Tool to sync Oracle DB environments, reads db objects, outputs as json, and generates install scripts

## Database objects

The project now includes a configuration table responsible for defining how installation scripts are produced:

- `INSTALL_SCRIPT_STRATEGY`: permite escolher entre gerar automaticamente os scripts a partir dos DDLs dos objectos (`generation_mode = 'DDL'`) ou apontar um script customizado com prefixos e sufixos opcionais para os nomes dos objectos (`generation_mode = 'CUSTOM'`).

O ficheiro [`sql/install_script_strategy.sql`](sql/install_script_strategy.sql) contem o DDL completo para criar a tabela, comentarios e trigger de auditoria que garante o preenchimento consistente das colunas de data.
