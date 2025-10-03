prompt creating nightly capture scheduler job and targets table

create table oei_env_sync_capture_targets (
    schema_name  varchar2(128) primary key,
    enabled      char(1) default 'Y' check (enabled in ('Y','N')),
    last_run     timestamp
);

comment on table oei_env_sync_capture_targets is 'List of schemas to capture nightly with enable flag and last run timestamp.';

begin
  dbms_scheduler.create_job(
    job_name        => 'OEI_ENV_SYNC_CAPTURE_JOB',
    job_type        => 'PLSQL_BLOCK',
    job_action      => q'[
declare
begin
  for r in (select schema_name from oei_env_sync_capture_targets where enabled = 'Y') loop
    oei_env_sync_capture_pkg.p_capture_schema(r.schema_name);
    update oei_env_sync_capture_targets
       set last_run = systimestamp
     where schema_name = r.schema_name;
  end loop;
end;] ',
    start_date      => systimestamp,
    repeat_interval => 'FREQ=DAILY;BYHOUR=2;BYMINUTE=0;BYSECOND=0',
    enabled         => true,
    comments        => 'Nightly capture of configured schemas');
exception when others then
  null; -- ignore if job exists or insufficient privileges
end;
/

