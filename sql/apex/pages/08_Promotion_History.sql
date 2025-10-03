-- Page: Promotion History (suggested Page 8)
-- Purpose: Show releases and install logs
-- Regions: Releases (IR), Install Log (IR)

-- Releases region query
select r.release_id,
       r.status,
       r.release_title,
       r.created_by,
       r.created_on,
       r.script_hash,
       dbms_lob.getlength(r.script_clob) as script_length
  from oei_env_sync_releases r
 order by r.release_id desc;
/

-- Install log region query
select l.install_id,
       l.release_id,
       l.target_schema,
       l.installed_by,
       l.installed_on,
       l.success,
       dbms_lob.getlength(l.log_clob) as log_length
  from oei_env_sync_install_log l
 order by l.install_id desc;
/

