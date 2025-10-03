prompt creating table oei_env_sync_object_exclude (patterns to skip during capture)

create table oei_env_sync_object_exclude (
    object_type  varchar2(30),
    name_like    varchar2(400) not null
);

comment on table oei_env_sync_object_exclude is 'List of patterns to exclude from capture. Use SQL LIKE syntax in NAME_LIKE.';
comment on column oei_env_sync_object_exclude.object_type is 'Oracle object type to apply the filter to; NULL means apply to all types.';

-- Seed sensible defaults to ignore system-generated or recycle bin objects
merge into oei_env_sync_object_exclude t
using (
  select cast(null as varchar2(30)) object_type, 'BIN$%' name_like from dual union all
  select 'INDEX',   'SYS_%' from dual union all
  select 'TRIGGER', 'SYS_%' from dual
) s
on (nvl(t.object_type, '#') = nvl(s.object_type, '#') and upper(t.name_like) = upper(s.name_like))
when not matched then insert (object_type, name_like) values (s.object_type, s.name_like);

