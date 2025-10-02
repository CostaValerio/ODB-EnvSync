prompt creating table oei_install_script_type_mode (per-type generation mode)

create table oei_install_script_type_mode (
    object_type     varchar2(30)  primary key,
    generation_mode varchar2(20)  not null,
    constraint ck_istm_mode check (generation_mode in ('DDL','DIFF'))
);

comment on table oei_install_script_type_mode is 'Defines generation mode per object type: DDL (full create) or DIFF (attempt ALTER).';
comment on column oei_install_script_type_mode.object_type is 'Oracle object type (e.g., TABLE, INDEX, VIEW, PACKAGE, PACKAGE BODY, PROCEDURE, FUNCTION, TRIGGER).';
comment on column oei_install_script_type_mode.generation_mode is 'DDL or DIFF';

-- sensible defaults: try DIFF for TABLE and INDEX; DDL for the rest
merge into oei_install_script_type_mode t
using (
  select 'TABLE' object_type, 'DIFF' generation_mode from dual union all
  select 'INDEX', 'DIFF' from dual union all
  select 'VIEW', 'DDL' from dual union all
  select 'SEQUENCE', 'DDL' from dual union all
  select 'TRIGGER', 'DDL' from dual union all
  select 'PACKAGE', 'DDL' from dual union all
  select 'PACKAGE BODY', 'DDL' from dual union all
  select 'PROCEDURE', 'DDL' from dual union all
  select 'FUNCTION', 'DDL' from dual
) s
on (t.object_type = s.object_type)
when matched then update set t.generation_mode = s.generation_mode
when not matched then insert (object_type, generation_mode) values (s.object_type, s.generation_mode);

