--**********************************************************
-- dump db security info.
-- input: &1 (mVersoin)
-- output:
--   4-security.xml
--**********************************************************
variable v_dumpver varchar2(20);
exec :v_dumpver := '&1';

whenever sqlerror continue;
alter session set nls_date_format='yyyy-mm-dd hh24:mi:ss';

set echo off feedback off trimspool on trimout on 
--set termout off  # no include script

set heading off
col value for a15
col X_X for a3

--=========================================================

spool 3-security.xml

select '<DB_HEALTH_CHECK_DATA versoin="'|| :v_dumpver || '">' ||  chr(10)||
       '<DATABASE type="Oracle">'             ||  chr(10)||
       '  <SECURITY>' from dual;

select '    <HC_DB_SCN           v="' || CURRENT_SCN ||'"/>' from v$database;
select '    <HC_AUDIT_STRATEGY   v="' || value  ||'"/>' from v$parameter where name='audit_trail';
select '    <HC_DB_AUDTAB_SIZEM  v="' || round(bytes/1048576) || ' MB"/>' from dba_segments
    where segment_name='AUD$' and rownum=1;

set heading on
col namespace for a12
col comments for a70
prompt <HC_PATCH_INFO>
select '   ' X_X,to_char(ACTION_TIME,'yyyy/mm/dd'),NAMESPACE,COMMENTS from dba_registry_history where ACTION_TIME is not null;
prompt </HC_PATCH_INFO>

prompt <HC_USE_SYS_TBS>
col username for a20
col default_tablespace for a20
select '   ' X_X, username, 'OPEN', default_tablespace
  from dba_users where account_status='OPEN' and username not like 'SYS%' 
  and username <> 'MGMT_VIEW'
  and default_tablespace = 'SYSTEM';
prompt </HC_USE_SYS_TBS>

prompt <HC_DBA_GRANTED>
col grantee for a20
select '   ' X_X,grantee, granted_role from dba_role_privs
  where granted_role='DBA' and grantee not in ('SYS', 'SYSTEM');
prompt </HC_DBA_GRANTED>

prompt <HC_PROFILE_PASSWD>
col profile for a20
col resource_name for a30
col limit for a30
select '   ' X_X,PROFILE,RESOURCE_NAME,LIMIT FROM DBA_PROFILES
  WHERE RESOURCE_TYPE='PASSWORD' ORDER BY PROFILE,RESOURCE_NAME;
prompt </HC_PROFILE_PASSWD>

col USERNAME for a20
col ACCOUNT_STATUS for a6
prompt <HC_USER_STATUS>
select '   ' X_X,USERNAME,ACCOUNT_STATUS,EXPIRY_DATE
  FROM DBA_USERS where account_status = 'OPEN' and username not like 'SYS%' ORDER BY 2;
prompt </HC_USER_STATUS>

set heading off
select '  </SECURITY>'   ||  chr(10)||
       '</DATABASE>'     ||  chr(10)||
       '</DB_HEALTH_CHECK_DATA>'  from dual;

spool off
