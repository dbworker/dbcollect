--**********************************************************
-- dump db basic info.
-- input: &1 (mVersoin)
-- output:
--   2-database.xml
--   misc.out
--**********************************************************
variable v_dumpver varchar2(20);
exec :v_dumpver := '&1';

whenever sqlerror continue;
alter session set nls_date_format='yyyy-mm-dd hh24:mi:ss';

set serveroutput on size 1000000
set echo off feedback off trimspool on trimout on 
--set termout off  # no include script
set long 1000000 pagesize 2000 linesize 1000
--set numwidth 15

set heading off
col value for a10
--=========================================================

spool 2-database.xml

-- TODO: use XML template? complex, and replace element not easy without python
select '<DB_HEALTH_CHECK_DATA versoin="'|| :v_dumpver || '">' ||  chr(10)||
       '<DATABASE type="Oracle">'             ||  chr(10)||
       '  <INSTANCE>' from dual;
select '    <HC_DB_NAME          v="' || name           ||'"/>' ||  chr(10)||
       '    <HC_DB_ID            v="' || dbid           ||'"/>' from v$database;
select '    <HC_DB_VERSION       v="' || version        ||'"/>' ||  chr(10)||
       '    <HC_INSTANCE_NAME    v="' || instance_name  ||'"/>' ||  chr(10)||
       '    <HC_IS_RAC           v="' || parallel       ||'"/>' from v$instance;
select '    <HC_INSTANCE_COUNT   v="' || count(*)       ||'"/>' from gv$instance;
select '    <HC_DB_CHARSET      v="' || value    ||'"/>' from v$nls_parameters where parameter='NLS_CHARACTERSET';
select '    <HC_LOG_MODE         v="' || log_mode       ||'"/>' from v$database;
select '    <HC_SGA_SIZE         v="' || ROUND(sum(value)/1024/1024)||' MB"/>' from v$sga;
select '    <HC_DB_BLOCK_SIZE    v="' || value    ||'"/>' from v$parameter where name='db_block_size';
select '    <HC_TABLESPACE_COUNT v="' || count(*) ||'"/>' from v$tablespace;
select '    <HC_DB_USED_SPACE    v="' || ROUND(sum(bytes)/1024/1024)||' MB"/>' ||  chr(10)||
       '    <HC_DATAFILE_COUNT   v="' || count(*) ||'"/>' from dba_data_files;
select '    <HC_TEMPFILE_COUNT   v="' || count(*) ||'"/>' from dba_temp_files;
select '    <HC_CONTROL_NUM      v="' || count(*) ||'"/>' from v$controlfile;
select '    <HC_REDO_MINSIZE     v="' || ROUND(MIN(BYTES)/1024/1024)||' MB"/>' ||  chr(10)||
       '    <HC_REDO_GROUPS      v="' || count(*) ||'"/>' ||  chr(10)||
       '    <HC_REDO_MEMBERS     v="' || MIN(MEMBERS)||'"/>'    from v$log ;
select '    <HC_PARAM_PROCESSES  v="' || value    ||'"/>'       from v$parameter where name='processes';
select '    <HC_MAX_CONNECTIONS  v="' || max_utilization||'"/>' from v$resource_limit where resource_name='processes';

set lines 200 pages 200
col name for a30
col value for a50

select '    <HC_DB_PARAMETERS>' from dual;
select '   ', name, substr(value,1,50) value from v$parameter where isdefault = 'FALSE' order by name;
select '    </HC_DB_PARAMETERS>' from dual;
select '  </INSTANCE>' from dual;

---------------------------------------
prompt @@_@@
select '  <DB_FILES>' from dual;

set heading on

-- column '   ' is used for left-padding indent, see FormatOracleXml()
col name for a60
col file_size for a10
prompt <HC_CONTROL_FILES>
select '   ', name,round(block_size*file_size_blks/1024/1024)||'M' file_size from v$controlfile;
prompt </HC_CONTROL_FILES>

col group# for 999
col member for a50
prompt <HC_REDO_FILES>
select '   ',group#,type,member from v$logfile order by group#;
prompt </HC_REDO_FILES>

col sequence# for 9999999
prompt <HC_REDO_ROTATE>
select '   ',THREAD#,GROUP#,BYTES,sequence#,STATUS,FIRST_TIME from v$log order by thread#, sequence#;
prompt </HC_REDO_ROTATE>

col first_time for a20
col thread# for 9999
prompt <HC_REDO_SWITCH_COUNT>
select '   ',thread#, to_char(first_time, 'yyyy-mm-dd') first_time, count(*)
  from v$log_history
    where first_time between trunc(sysdate - 30) and trunc(sysdate)
      group by thread#, to_char(first_time, 'yyyy-mm-dd')
      order by thread#, 3;
prompt </HC_REDO_SWITCH_COUNT>

prompt <HC_TABLESPACE_USAGE>
col tablespace_name for a18
col Size_GB for 999999
col percent for a6
select '   ',tablespace_name,
    round(tablespace_size * value / 1073741824) Size_GB,
    round(used_percent, 1)||'%' percent
  from dba_tablespace_usage_metrics, v$parameter
    where name = 'db_block_size' order by used_percent desc;
prompt </HC_TABLESPACE_USAGE>


prompt <HC_DATA_FILES>
col file_name for a50
col Size_MB for 999999
col TABLESPACE_NAME for a15
select '   ',substr(file_name,1,50) file_name, bytes/1024/1024 Size_MB, tablespace_name,AUTOEXTENSIBLE auto
  from dba_data_files where rownum<=20;
prompt </HC_DATA_FILES>

set heading off
select '    <HC_ARCHIVE_DEST     v=""/>' from dual;
select '    <HC_RECYCLEBIN_USED  v="' || nvl(round(sum(a.space*b.value/1024/1024)),0)||' MB"/>'
    from dba_recyclebin a ,v$parameter b where b.name='db_block_size';

select '    <HC_AWR_HOLD_DAYS    v="'|| to_number(substr(retention,2,6))||'"/>' from DBA_HIST_WR_CONTROL;
select '  </DB_FILES>' from dual;
---------------------------------------
prompt @@_@@
select '  <DB_OBJECTS>' from dual;

select '    <HC_INVALID_OBJECTS    v="'|| count(*)||'"/>' from dba_objects where status='INVALID';

set heading on
col Size_GB for a9
col name for a40
col segment_type for a15
prompt <HC_BIG_TABLES>
select '   ', owner||'.'||segment_name name, to_char(round(bytes/1073741824),'9999')||' GB' Size_GB,  segment_type
 from (
    select owner, segment_name,segment_type,bytes
    from dba_segments where bytes>1000000000 order by bytes desc
)where rownum<=15;
prompt </HC_BIG_TABLES>

col SQL_ID for a20
col sql_text for a50
col SCHEMA_NAME for a10
col RANKING for 99999
col COUNTS for 9999999
prompt <HC_SQL_NOT_BIND>
with force_mathces as
 (select l.force_matching_signature,
         max(l.sql_id || l.child_number) max_sql_child,
         dense_rank() over(order by count(*) desc) ranking,
         count(*) counts
    from v$sql l
   where l.force_matching_signature <> 0
     and l.parsing_schema_name <> 'SYS'
   group by l.force_matching_signature
  having count(*) > 10)
select '   ',v.sql_id,
       substr(v.sql_text,0,50) sql_text,
       v.parsing_schema_name schema_name,
       fm.ranking,
       fm.counts
  from force_mathces fm, v$sql v
 where fm.max_sql_child = (v.sql_id || v.child_number)
   and fm.ranking <= 50
   and rownum < 10
 order by fm.ranking;
prompt </HC_SQL_NOT_BIND>

col vc for 99999
col sql_id for a14
col sqltext for a60
prompt <HC_SQL_VC_INFO>
select * from (select '   ',VERSION_COUNT vc, SQL_ID,substr(SQL_TEXT,1,60) "sqltext" from v$sqlarea order by SQL_TEXT desc) where rownum<=10;
prompt </HC_SQL_VC_INFO>

col name for a40
prompt <HC_SGA_INFO>
select '   ', t.* from v$sgainfo t;
prompt </HC_SGA_INFO>

set heading off
select '  </DB_OBJECTS>' ||  chr(10)||
       '</DATABASE>'     ||  chr(10)||
       '</DB_HEALTH_CHECK_DATA>'  from dual;

spool off
