prompt ================================================================================
prompt ODB-EnvSync - Check Core Install Objects (expect 16 rows, all OK)
prompt ================================================================================

-- Expected rows: 16
-- Run as the same schema you installed into

with expected (object_type, object_name) as (
  select 'TABLE','OEI_INSTALL_SCRIPT_STRATEGY'        from dual union all
  select 'TABLE','OEI_INSTALL_SCRIPT_STRATEGY_NAMING' from dual union all
  select 'TRIGGER','TRG_INSTALL_SCRIPT_STRATEGY_AUDIT'from dual union all
  select 'TABLE','OEI_INSTALL_SCRIPT_TYPE_MODE'       from dual union all
  select 'TABLE','OEI_ENV_SYNC_SCHEMA_OBJECTS'        from dual union all
  select 'TABLE','OEI_ENV_SYNC_SNAPSHOTS'             from dual union all
  select 'TABLE','OEI_ENV_SYNC_RELEASES'              from dual union all
  select 'TABLE','OEI_ENV_SYNC_INSTALL_LOG'           from dual union all
  select 'TABLE','OEI_ENV_SYNC_AUDIT'                 from dual union all
  select 'TRIGGER','OEI_ENV_SYNC_AUDIT_TRG'           from dual union all
  select 'PROCEDURE','OEI_ENV_SYNC_AUDIT_ENABLE'      from dual union all
  select 'PROCEDURE','OEI_ENV_SYNC_AUDIT_DISABLE'     from dual union all
  select 'TABLE','OEI_ENV_SYNC_SEED_TABLES'           from dual union all
  select 'TABLE','OEI_ENV_SYNC_OBJECT_EXCLUDE'        from dual union all
  select 'PACKAGE','PCK_OEI_ENV_SYNC'                 from dual union all
  select 'PACKAGE BODY','PCK_OEI_ENV_SYNC'            from dual
)
select e.object_type,
       e.object_name,
       case when u.object_name is not null then 'OK' else 'MISSING' end as existence,
       nvl(u.status, 'N/A') as compile_status,
       nvl(err.err_count, 0) as error_count
  from expected e
  left join user_objects u
    on u.object_type = e.object_type
   and u.object_name = e.object_name
  left join (
        select name, type, count(*) err_count
          from user_errors
         group by name, type
  ) err
    on err.name = e.object_name
   and err.type = e.object_type
 order by case when u.object_name is null then 0 else 1 end,
          case when u.status = 'VALID' then 1 else 0 end,
          e.object_type,
          e.object_name;

prompt --- Any rows below indicate missing or invalid objects (should be 0 rows)

with expected (object_type, object_name) as (
  select 'TABLE','OEI_INSTALL_SCRIPT_STRATEGY'        from dual union all
  select 'TABLE','OEI_INSTALL_SCRIPT_STRATEGY_NAMING' from dual union all
  select 'TRIGGER','TRG_INSTALL_SCRIPT_STRATEGY_AUDIT'from dual union all
  select 'TABLE','OEI_INSTALL_SCRIPT_TYPE_MODE'       from dual union all
  select 'TABLE','OEI_ENV_SYNC_SCHEMA_OBJECTS'        from dual union all
  select 'TABLE','OEI_ENV_SYNC_SNAPSHOTS'             from dual union all
  select 'TABLE','OEI_ENV_SYNC_RELEASES'              from dual union all
  select 'TABLE','OEI_ENV_SYNC_INSTALL_LOG'           from dual union all
  select 'TABLE','OEI_ENV_SYNC_AUDIT'                 from dual union all
  select 'TRIGGER','OEI_ENV_SYNC_AUDIT_TRG'           from dual union all
  select 'PROCEDURE','OEI_ENV_SYNC_AUDIT_ENABLE'      from dual union all
  select 'PROCEDURE','OEI_ENV_SYNC_AUDIT_DISABLE'     from dual union all
  select 'TABLE','OEI_ENV_SYNC_SEED_TABLES'           from dual union all
  select 'TABLE','OEI_ENV_SYNC_OBJECT_EXCLUDE'        from dual union all
  select 'PACKAGE','PCK_OEI_ENV_SYNC'                 from dual union all
  select 'PACKAGE BODY','PCK_OEI_ENV_SYNC'            from dual
)
select e.object_type,
       e.object_name,
       case when u.object_name is null then 'MISSING' else u.status end as state
  from expected e
  left join user_objects u
    on u.object_type = e.object_type
   and u.object_name = e.object_name
 where u.object_name is null
    or u.status <> 'VALID'
 order by state, e.object_type, e.object_name;
