prompt creating table oei_env_sync_seed_tables (config for data seeds)

create table oei_env_sync_seed_tables (
    table_name    varchar2(128) primary key,
    where_clause  clob,
    enabled       char(1) default 'Y' check (enabled in ('Y','N'))
);

comment on table oei_env_sync_seed_tables is 'Config for tables whose data should be included as seed MERGE DML during install generation.';
comment on column oei_env_sync_seed_tables.where_clause is 'Optional WHERE filter to restrict rows included as seed data.';

