--**********************************************************
-- dump db basic info.
-- input: &1 (mVersoin)
-- output:
--   2-database.xml
--**********************************************************
variable v_dumpver varchar2(20);
variable v_ispdb varchar2(10);
variable v_pdbname varchar2(20);

exec :v_dumpver := '&1';
exec :v_ispdb := '&2';
exec :v_pdbname := '&3';

whenever sqlerror continue;
alter session set nls_date_format='yyyy-mm-dd hh24:mi:ss';

set serveroutput on size 1000000
set echo off feedback off trimspool on trimout on 
--set termout off  # no include script
set long 1000000 pagesize 2000 linesize 1000
--set numwidth 15

set heading off
col value for a10
col X_X for a3

--=========================================================

spool 2-database.xml

-- TODO: use XML template? complex, and replace element not easy without python
-- TODO: on PDB some v$ view will be null
---------------------------------------
-- instance:
--     basic info
---------------------------------------

select '<DB_HEALTH_CHECK_DATA versoin="'|| :v_dumpver || '">' ||  chr(10)||
       '<DATABASE type="Oracle">'             ||  chr(10)||
       '  <INSTANCE>' from dual;
select '    <HC_DB_NAME          v="' || name           ||'"/>' ||  chr(10)||
       '    <HC_DB_ID            v="' || dbid           ||'"/>' from v$database;
select '    <HC_ISPDB            v="' || :v_ispdb       ||'"/>' ||  chr(10)||
       '    <HC_PDB_NAME         v="' || :v_pdbname     ||'"/>' from dual;
select '    <HC_DB_VERSION       v="' || version        ||'"/>' ||  chr(10)||
       '    <HC_INSTANCE_NAME    v="' || instance_name  ||'"/>' ||  chr(10)||
       '    <HC_IS_RAC           v="' || parallel       ||'"/>' from v$instance;
select '    <HC_INSTANCE_COUNT   v="' || count(1)       ||'"/>' from gv$instance;
select '    <HC_DB_CHARSET       v="' || value    ||'"/>' from v$nls_parameters where parameter='NLS_CHARACTERSET';
select '    <HC_LOG_MODE         v="' || log_mode       ||'"/>' from v$database;
select '    <HC_SGA_SIZE         v="' || ROUND(sum(value)/1024/1024)||' MB"/>' from v$sga;
select '    <HC_DB_BLOCK_SIZE    v="' || value    ||'"/>' from v$parameter where name='db_block_size';
select '    <HC_TABLESPACE_COUNT v="' || count(1) ||'"/>' from v$tablespace;
select '    <HC_DB_USED_SPACE    v="' || ROUND(sum(bytes)/1024/1024)||' MB"/>' ||  chr(10)||
       '    <HC_DATAFILE_COUNT   v="' || count(1) ||'"/>' from dba_data_files;
select '    <HC_TEMPFILE_COUNT   v="' || count(1) ||'"/>' from dba_temp_files;
select '    <HC_CONTROL_NUM      v="' || count(1) ||'"/>' from v$controlfile;
select '    <HC_REDO_MINSIZE     v="' || ROUND(MIN(BYTES)/1024/1024)||' MB"/>' ||  chr(10)||
       '    <HC_REDO_GROUPS      v="' || count(1) ||'"/>' ||  chr(10)||
       '    <HC_REDO_MEMBERS     v="' || MIN(MEMBERS)||'"/>'    from v$log ;
select '    <HC_PARAM_PROCESSES  v="' || value    ||'"/>'       from v$parameter where name='processes';
select '    <HC_MAX_CONNECTIONS  v="' || nvl(max_utilization,-1)||'"/>' from v$resource_limit where resource_name='processes';
select '    <HC_AWR_HOLD_DAYS    v="'|| to_number(substr(retention,2,6))||'"/>' from DBA_HIST_WR_CONTROL where rownum<=1;

set lines 200 pages 2000
col name for a45
col value for a50

set heading on
prompt <HC_DB_PARAMETERS>
select '   ' X_X, name, substr(nvl(value,'null'),1,50) value from v$parameter
    where isdefault = 'FALSE'
    order by name;
prompt </HC_DB_PARAMETERS>

col value for a30
prompt <HC_DB_SPEC_PARAMS>
select '   ' X_X, name, substr(nvl(value,'null'),1,30) value, isdefault from v$parameter
    where name in (
        'cell_offload_processing',
        'db_files',
        'db_recovery_file_dest',
        'db_recovery_file_dest_size',
        'deferred_segment_creation',
        'log_archive_config',
        'log_archive_dest_2',
        'memory_max_target',
        'open_cursors',
        'optimizer_adaptive_features',
        'parallel_force_local',
        'parallel_max_servers',
        'recyclebin',
        'remote_login_passwordfile',
        'result_cache_max_size',
        'sec_case_sensitive_logon',
        'spfile',
        'sga_max_size',
        'sga_target',
        'undo_retention'
    )
union all
select '   ' X_X, KSPPINM name, substr(nvl(KSPPSTVL,'null'),1,30) value,
decode(bitand(ksppstvf, 7),
              1,
              'FALSE',
              4,
              'SysMod',
              'TRUE') isdefault
from x$ksppi a, x$ksppsv b
    where a.indx = b.indx
        and KSPPINM in (
        '_gc_policy_time',
        '_gc_undo_affinity',
        '_optimizer_extended_cursor_sharing_rel',
        '_optimizer_extended_cursor_sharing',
        '_optimizer_adaptive_cursor_sharing',
        '_optimizer_mjc_enabled',
        '_optimizer_null_aware_antijoin',
        '_optimizer_use_feedback',
        '_undo_autotune',
        '_use_adaptive_log_file_sync',
        '_use_single_log_writer'
    )
order by name;
prompt </HC_DB_SPEC_PARAMS>

set heading off
select '  </INSTANCE>' from dual;

---------------------------------------
-- files info:
--     datafile, controlfile, redofile
-- space usage:
--     tablespace, recyclebin
---------------------------------------

prompt @@_@@
select '  <DB_FILES>' from dual;
select '    <HC_TABLESPACE_UMAX  v="' || round(max(used_percent), 1)||'"/>' from dba_tablespace_usage_metrics;

set heading on
col tablespace_name for a18
col Size_GB for 999999
col percent for a6
prompt <HC_TABLESPACE_USAGE>
select * from (
  select '   ' X_X,tablespace_name,
      round(tablespace_size * value / 1073741824) Size_GB,
      round(used_percent, 1)||'%' percent
    from dba_tablespace_usage_metrics, v$parameter
      where name = 'db_block_size' order by used_percent desc
) where rownum <= 10;
prompt </HC_TABLESPACE_USAGE>

-- column '   ' is used for left-padding indent, see FormatOracleXml()
col name for a60
col file_size for a10
prompt <HC_CONTROL_FILES>
select '   ' X_X, name,round(block_size*file_size_blks/1024/1024)||'M' file_size from v$controlfile;
prompt </HC_CONTROL_FILES>

col group# for 999
col member for a50
prompt <HC_REDO_FILES>
select '   ' X_X,group#,type,member from v$logfile order by group#;
prompt </HC_REDO_FILES>

col sequence# for 9999999
prompt <HC_REDO_ROTATE>
select '   ' X_X,THREAD#,GROUP#,BYTES,sequence#,STATUS,FIRST_TIME from v$log order by thread#, sequence#;
prompt </HC_REDO_ROTATE>

col first_time for a20
col thread# for 9999
prompt <HC_REDO_SWITCH_COUNT>
select '   ' X_X,thread#, to_char(first_time, 'yyyy-mm-dd') first_time, count(*)
  from v$log_history
    where first_time between trunc(sysdate - 7) and trunc(sysdate)
      group by thread#, to_char(first_time, 'yyyy-mm-dd')
      order by 2, 3;
prompt </HC_REDO_SWITCH_COUNT>

prompt <HC_DATA_FILES>
col file_name for a50
col Size_MB for 999999
col TABLESPACE_NAME for a25
select '   ' X_X,substr(file_name,1,50) file_name, bytes/1024/1024 Size_MB, tablespace_name,AUTOEXTENSIBLE auto
  from dba_data_files where rownum<=20;
prompt </HC_DATA_FILES>

set heading off
--select '    <HC_ARCHIVE_DEST     v=""/>' from dual;
select '    <HC_RECYCLEBIN_USED  v="' || nvl(round(sum(a.space*b.value/1024/1024)),0)||' MB"/>'
    from dba_recyclebin a ,v$parameter b where b.name='db_block_size';

select '  </DB_FILES>' from dual;

---------------------------------------
-- object info:
--     table, index, dblink, trigger, etc.
--     big table, big part, overmuch index
--     sql
---------------------------------------

prompt @@_@@
select '  <DB_OBJECTS>' from dual;
select '    <HC_OBJECT_ID_MAX    v="'|| max(object_id)||'"/>' from dba_objects;
select '    <HC_TABLE_COUNT      v="' || count(1)    ||'"/>'    from dba_tables
    where owner in (select username from dba_users where account_status='OPEN' and username not like 'SYS%');
select '    <HC_DBLINK_COUNT     v="' || count(1)    ||'"/>'    from dba_db_links;
select '    <HC_TRIGGER_COUNT    v="' || count(1)    ||'"/>'    from dba_triggers
    where owner in (select username from dba_users where account_status='OPEN' and username not like 'SYS%');

select '    <HC_INVALID_OBJECTS  v="'|| count(1)||'"/>' from dba_objects where status='INVALID';

-- table
select '    <HC_TABLE_USE_LONG   v="'|| count(1)||'"/>' from dba_tab_columns where data_type like 'LONG%'
    and owner in (select username from dba_users where account_status='OPEN' and username not like 'SYS%');

set heading on
col object_name for a30
col owner for a20
prompt <HC_TABLE_NAME_LOWERCASE>
select '   ' X_X, owner, OBJECT_NAME, OBJECT_TYPE from dba_objects
    where regexp_like (object_name, '^[a-z]','c')  and object_type like 'TABLE%'
    and owner in (select username from dba_users where account_status='OPEN' and username not like 'SYS%')
    and rownum<=10;
prompt </HC_TABLE_NAME_LOWERCASE>

col Size_GB for a9
col name for a40
col segment_type for a15
prompt <HC_BIG_TABLES>
select '   ' X_X, owner||'.'||segment_name name, to_char(round(bytes/1073741824),'9999')||' GB' Size_GB,  segment_type
 from (
    select owner, segment_name,segment_type,bytes
    from dba_segments where bytes>5000000000 and segment_type like 'TABLE%' order by bytes desc
)where rownum<=10;
prompt </HC_BIG_TABLES>

set heading off
select '    <HC_PTABLE_PARTS_MAX v="'|| nvl(max(partition_count),0)||'"/>' from dba_part_tables
    where interval is null
    and owner in (select username from dba_users where account_status='OPEN' and username not like 'SYS%');

set heading on
col owner for a20
col table_owner for a20
col table_name for a30
prompt <HC_PTABLE_PARTS_TOPCNT>
select * from (
    select '   ' X_X, owner, table_name,PARTITIONING_TYPE, PARTITION_count from dba_part_tables
    where interval is null and owner in (select username from dba_users where account_status='OPEN' and username not like 'SYS%')
    order by partition_count desc
) where rownum <=10;
prompt </HC_PTABLE_PARTS_TOPCNT>


set heading off
-- index
select '    <HC_INDEX_COLS_MAX   v="'|| max(count(1))||'"/>' from dba_ind_columns
    where index_owner in (select username from dba_users where account_status='OPEN' and username not like 'SYS%')
    group by index_owner, index_name;
select '    <HC_TABLE_IDXS_MAX   v="'|| max(count(1))||'"/>' from dba_indexes
    where table_owner in (select username from dba_users where account_status='OPEN' and username not like 'SYS%')
    group by table_owner, table_name;

set heading on
prompt <HC_INDEX_OVERMUCH>
select * from (
    select '   ' X_X, table_owner, table_name, count(1) cnt from dba_indexes
    where table_owner in (select username from dba_users where account_status='OPEN' and username not like 'SYS%')
    group by table_owner, table_name having(count(1)>6)
    order by cnt desc
) where rownum<=5;
prompt </HC_INDEX_OVERMUCH>

-- sequence
set heading off
select '    <HC_DB_NOCACHE_BIG_SEQ v="'|| nvl(count(1),0)||'"/>' from dba_sequences 
    where cache_size=0 and LAST_NUMBER > 100000
    and SEQUENCE_OWNER in (select username from dba_users where account_status='OPEN' and username not like 'SYS%') ;

set heading on
col SEQUENCE_OWNER for a20
col SEQUENCE_NAME for a30
prompt <HC_DB_NOCACHE_SEQS>
select * from (
    select '   ' X_X, SEQUENCE_OWNER, SEQUENCE_NAME, LAST_NUMBER, CACHE_SIZE from dba_sequences
    where cache_size=0
    and SEQUENCE_OWNER in (select username from dba_users where account_status='OPEN' and username not like 'SYS%')
    order by LAST_NUMBER desc
) where rownum<=5;
prompt </HC_DB_NOCACHE_SEQS>

set heading off
select '    <HC_SEQ_HIGH_PCTUSED_COUNT v="'|| nvl(count(1),0)||'"/>' from dba_sequences 
    where last_number/max_value > 0.55;

set heading on
col CACHE for 99999
col PCTUSED for a5
prompt <HC_HIGH_PCTUSED_SEQS>
select * from (
    select '   ' X_X, SEQUENCE_OWNER, SEQUENCE_NAME, MAX_VALUE, CYCLE_FLAG,
    ORDER_FLAG, CACHE_SIZE CACHE, LAST_NUMBER,
    to_char((last_number/max_value),'0.99') PCTUSED from dba_sequences
    where last_number/max_value > 0.55
    order by PCTUSED desc
) where rownum<=10;
prompt </HC_HIGH_PCTUSED_SEQS>

-- sql
col SQL_ID for a20
col sql_text for a50
col SCHEMA_NAME for a10
col RANKING for 99999
col COUNTS for 9999999
prompt <HC_SQL_NOT_BIND>
with force_matches as
 (select l.force_matching_signature,
         max(l.sql_id || l.child_number) max_sql_child,
         dense_rank() over(order by count(*) desc) ranking,
         count(*) counts
    from v$sql l
   where l.force_matching_signature <> 0
     and l.parsing_schema_name <> 'SYS'
   group by l.force_matching_signature
  having count(*) > 10)
select '   ' X_X,v.sql_id,
       replace(replace(substr(SQL_TEXT,1,50),'&','&'||'amp;'),'<','&'||'lt;') sql_text,
       v.parsing_schema_name schema_name,
       fm.ranking,
       fm.counts
  from force_matches fm, v$sql v
 where fm.max_sql_child = (v.sql_id || v.child_number)
   and fm.ranking <= 50
   and rownum < 10
 order by fm.ranking;
prompt </HC_SQL_NOT_BIND>

set heading off
select '    <HC_SQL_VC_MAX       v="' || max(VERSION_COUNT) || '"/>' from v$sqlarea;

set heading on
col vc for 99999
col sql_id for a14
col SQL_TEXT for a60
prompt <HC_SQL_VC_INFO>
select * from (select '   ' X_X,VERSION_COUNT vc, SQL_ID,
    replace(replace(substr(SQL_TEXT,1,60),'&','&'||'amp;'),'<','&'||'lt;')  SQL_TEXT from v$sqlarea
    order by VERSION_COUNT desc) where rownum<=10;
prompt </HC_SQL_VC_INFO>

col name for a40
prompt <HC_SGA_INFO>
select '   ' X_X, t.* from v$sgainfo t;
prompt </HC_SGA_INFO>

set heading off
select '  </DB_OBJECTS>' from dual;

---------------------------------------
-- performance:
--     db cpu, db io, txn
--     big table, big part, overmuch index
---------------------------------------

prompt @@_@@
select '  <DB_PERFORMANCE>' from dual;

select '    <HC_MAX_PARALLELS    v="' || max_utilization||'"/>' from v$resource_limit
    where resource_name='parallel_max_servers';

variable v_instnum number;
variable v_beginid number;
variable v_endid number;
variable v_dbid number;


exec select instance_number into :v_instnum from v$instance;
exec select min(snap_id), max(snap_id) into :v_beginid, :v_endid from dba_hist_snapshot where instance_number=:v_instnum and end_interval_time between trunc(sysdate-1) and trunc(sysdate);
exec select dbid into :v_dbid from v$database;

-- TODO: if snap interval is half-hour then some calculate is wrong
set heading on
col snaptime for a18
prompt <HC_DB_CPU_IO_HOURLY>
select '   ' X_X,to_char(end_interval_time, 'yyyymmdd hh24:mi') snaptime,
round(X.diff)         elapse,
case when X.diff>Y.diff then round(Y.diff*100/X.diff) else 100 end "CPU%",
Z.rd_cnt              rd_cnt,
ceil(Z.rd_t/Z.rd_cnt) rd_ms,
W.wr_cnt              wr_cnt,
ceil(W.wr_t/W.wr_cnt) wr_ms
from
(
    select snap_id, (value - (lag(value, 1, null) over(order by snap_id)))/1000000 diff
    from dba_hist_sys_time_model 
    where instance_number = :v_instnum and snap_id between :v_beginid and :v_endid
    and dbid = :v_dbid and stat_name= 'DB time'
) X,
(
    select snap_id, (value - (lag(value, 1, null) over(order by snap_id)))/1000000 diff
    from dba_hist_sys_time_model 
    where instance_number = :v_instnum and snap_id between :v_beginid and :v_endid
    and dbid = :v_dbid and stat_name= 'DB CPU'
) Y,
(
    select snap_id,
    1+(total_waits - (lag(total_waits, 1, null) over(order by snap_id))) rd_cnt, -- +1 avoid divid 0
    ( (time_waited_micro - lag(time_waited_micro, 1, null) over(order by snap_id))/1000 ) rd_t
    from dba_hist_system_event
    where instance_number = :v_instnum and snap_id between :v_beginid and :v_endid
    and dbid = :v_dbid and event_name = 'db file sequential read'
) Z,
(
    select snap_id,
    1+(total_waits - (lag(total_waits, 1, null) over(order by snap_id))) wr_cnt,
    ( (time_waited_micro - lag(time_waited_micro, 1, null) over(order by snap_id))/1000 ) wr_t
    from dba_hist_system_event
    where instance_number = :v_instnum and snap_id between :v_beginid and :v_endid
    and dbid = :v_dbid and event_name = 'log file sync'
) W, dba_hist_snapshot sp
where sp.instance_number = :v_instnum and sp.snap_id between :v_beginid and :v_endid
and sp.dbid = :v_dbid
and sp.snap_id = X.snap_id
and sp.snap_id = Y.snap_id
and sp.snap_id = Z.snap_id
and sp.snap_id = W.snap_id
order by 2;
prompt </HC_DB_CPU_IO_HOURLY>

prompt <HC_DB_RW_TX_HOURLY>
select '   ' X_X,to_char(end_interval_time, 'yyyymmdd hh24:mi') snaptime,
round(X.diff)   dbreads,
round(Y.diff)   dbchanges,
round(Z.diff,1) logons,
round(W.diff,1) commits,
round(V.diff,1) rollbacks
from 
(
    select snap_id, (value - (lag(value, 1, null) over(order by snap_id)))/3600 diff
    from dba_hist_sysstat
    where instance_number = :v_instnum and snap_id between :v_beginid and :v_endid
    and dbid = :v_dbid and stat_name= 'consistent gets'
)X,
(
    select snap_id, (value - (lag(value, 1, null) over(order by snap_id)))/3600 diff
    from dba_hist_sysstat
    where instance_number = :v_instnum and snap_id between :v_beginid and :v_endid
    and dbid = :v_dbid and  stat_name= 'db block changes'
)Y,
(
    select snap_id, (value - (lag(value, 1, null) over(order by snap_id)))/3600 diff
    from dba_hist_sysstat
    where instance_number = :v_instnum and snap_id between :v_beginid and :v_endid
    and dbid = :v_dbid and stat_name= 'logons cumulative'
)Z,
(
    select snap_id, (value - (lag(value, 1, null) over(order by snap_id)))/3600 diff
    from dba_hist_sysstat
    where instance_number = :v_instnum and snap_id between :v_beginid and :v_endid
    and dbid = :v_dbid and stat_name= 'user commits'
)W,
(
    select snap_id, (value - (lag(value, 1, null) over(order by snap_id)))/3600 diff
    from dba_hist_sysstat
    where instance_number = :v_instnum and snap_id between :v_beginid and :v_endid
    and dbid = :v_dbid and stat_name= 'transaction rollbacks'
)V, dba_hist_snapshot sp
where sp.instance_number = :v_instnum and sp.snap_id between :v_beginid and :v_endid
and sp.dbid = :v_dbid
and sp.snap_id = X.snap_id
and sp.snap_id = Y.snap_id
and sp.snap_id = Z.snap_id
and sp.snap_id = W.snap_id
and sp.snap_id = V.snap_id
order by 2;
prompt </HC_DB_RW_TX_HOURLY>

-- TODO: v$active_session_history
set heading off
select '  </DB_PERFORMANCE>' from dual;

---------------------------------------
-- RAC:
--     gc blocks lost, net traffic
--     gc statistics, gc msg
---------------------------------------

prompt @@_@@
select '  <DB_CLUSTER>' from dual;

variable v_instcnt number;
exec select count(1) into :v_instcnt from gv$instance;

-- TODO
select '    <HC_RAC_BLOCKS_LOST  v="' || max(value) || '"/>'
    from dba_hist_sysstat where dbid = :v_dbid and instance_number = :v_instnum
    and stat_name ='gc blocks lost' and :v_instcnt > 1
    and snap_id > :v_beginid;

set heading on
prompt <HC_RAC_BLOCKLOST_DAILY>
select '   ' X_X,to_char(end_interval_time, 'yyyy-mm-dd') snaptime,
round((value - (lag(value, 1, null) over(order by snap_id)))) lost
from
(
    select a.snap_id, end_interval_time, value value
    from dba_hist_sysstat a, dba_hist_snapshot b
    where a.dbid = :v_dbid and b.dbid = :v_dbid
    and a.instance_number = :v_instnum and b.instance_number = :v_instnum
    and stat_name ='gc blocks lost'
    and end_interval_time between trunc(sysdate-8) and trunc(sysdate)
    and a.snap_id = b.snap_id
    and to_char(end_interval_time, 'hh24') = '00'
    and :v_instcnt > 1
);
prompt </HC_RAC_BLOCKLOST_DAILY>

prompt <HC_RAC_TRAFFIC_MB_HOURLY>
select '   ' X_X,to_char(end_interval_time, 'yyyymmdd hh24:mi') snaptime,
round((value - (lag(value, 1, null) over(order by snap_id)))*8192/1048576/3600) rac_sizem
from
(
    select a.snap_id, end_interval_time, sum(value) value
    from dba_hist_sysstat a, dba_hist_snapshot b
    where a.dbid = :v_dbid and b.dbid = :v_dbid
    and a.instance_number = :v_instnum and b.instance_number = :v_instnum
    and (stat_name like 'gc%blocks received' or stat_name like 'gc%blocks served')
    and end_interval_time between trunc(sysdate-1) and trunc(sysdate)
    and a.snap_id = b.snap_id
    and :v_instcnt > 1
    group by a.snap_id, end_interval_time
);
prompt </HC_RAC_TRAFFIC_MB_HOURLY>

prompt <HC_RAC_STATS_HOURLY>
select '   ' X_X,to_char(end_interval_time, 'yyyymmdd hh24:mi') snaptime,
ceil(X.diff)              cr_recv,
round(Y.diff/X.diff*10,1) cr_recv_ms,
ceil(Z.diff)              cur_recv,
round(W.diff/Z.diff*10,1) cur_recv_ms
from 
(
    select snap_id, 1+(value - (lag(value, 1, null) over(order by snap_id)))/3600 diff
    from dba_hist_sysstat
    where instance_number = :v_instnum and snap_id between :v_beginid and :v_endid
    and stat_name= 'gc cr blocks received'
)X,
(
    select snap_id, (value - (lag(value, 1, null) over(order by snap_id)))/3600 diff
    from dba_hist_sysstat
    where instance_number = :v_instnum and snap_id between :v_beginid and :v_endid
    and stat_name= 'gc cr block receive time'
)Y,
(
    select snap_id, 1+(value - (lag(value, 1, null) over(order by snap_id)))/3600 diff
    from dba_hist_sysstat
    where instance_number = :v_instnum and snap_id between :v_beginid and :v_endid
    and stat_name= 'gc current blocks received'
)Z,
(
    select snap_id, (value - (lag(value, 1, null) over(order by snap_id)))/3600 diff
    from dba_hist_sysstat
    where instance_number = :v_instnum and snap_id between :v_beginid and :v_endid
    and stat_name= 'gc current block receive time'
)W, dba_hist_snapshot sp
where sp.instance_number = :v_instnum
and sp.snap_id = X.snap_id
and sp.snap_id = Y.snap_id
and sp.snap_id = Z.snap_id
and sp.snap_id = W.snap_id
and :v_instcnt > 1
order by 2;
prompt </HC_RAC_STATS_HOURLY>

prompt <HC_RAC_MSG_HOURLY>
select '   ' X_X,to_char(end_interval_time, 'yyyymmdd hh24:mi') snaptime,
ceil(X.diff)              msg,
round(Y.diff/X.diff*10,1) msg_ms
from
(
    select snap_id, 1+(value - (lag(value, 1, null) over(order by snap_id)))/3600 diff
    from dba_hist_dlm_misc
    where instance_number = :v_instnum and snap_id between :v_beginid and :v_endid
    and name= 'msgs sent queued on ksxp'
)X,
(
    select snap_id, (value - (lag(value, 1, null) over(order by snap_id)))/3600 diff
    from dba_hist_dlm_misc
    where instance_number = :v_instnum and snap_id between :v_beginid and :v_endid
    and name= 'msgs sent queue time on ksxp (ms)'
)Y, dba_hist_snapshot sp
where sp.instance_number = :v_instnum
and sp.snap_id = X.snap_id
and sp.snap_id = Y.snap_id
and :v_instcnt > 1
order by 2;
prompt </HC_RAC_MSG_HOURLY>


set heading off
select '    <HC_ASM_DG_UMAX      v="' || max(round((TOTAL_MB-FREE_MB)*100/TOTAL_MB)) || '"/>'
from v$asm_diskgroup ;

set heading on
prompt <HC_ASM_DG_USAGE>
select '   ' X_X, name, type, TOTAL_MB, FREE_MB, round((TOTAL_MB-FREE_MB)*100/TOTAL_MB) USAGE from v$asm_diskgroup
    order by usage desc;
prompt </HC_ASM_DG_USAGE>

col disk for a20
col path for a40
col group_name for a15
prompt <HC_ASM_DISK>
select '   ' X_X, a.name disk, path, a.TOTAL_MB, a.free_mb, b.name group_name from v$asm_disk a, v$asm_diskgroup b
    where a.group_number=b.group_number order by group_name, disk;
prompt </HC_ASM_DISK>


set heading off
select '  </DB_CLUSTER>' ||  chr(10)||
       '</DATABASE>'     ||  chr(10)||
       '</DB_HEALTH_CHECK_DATA>'  from dual;

spool off
