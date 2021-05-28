#**********************************************************
# dump rman backup info.
# input: mVersoin, misc.out
# output:
#   5-backup.xml when archive mode
#**********************************************************

WLOG()
{
    echo "[`date +'%Y-%m-%d %H:%M:%S'`]$1"| tee -a ../dump.log
}

mLogMode=`head -7 misc.out  |tail -1`
if [ "$mLogMode" == "NOARCHIVELOG" ]; then
    WLOG "[$0][info] no backup info with NOARCHIVELOG mode."
    exit
fi

mVersion="$1"

sqlplus -S "/ as sysdba" << EOF
variable v_dumpver varchar2(20);
exec :v_dumpver := '$mVersion';

whenever sqlerror continue;
alter session set nls_date_format='yyyy-mm-dd hh24:mi:ss';
set echo off feedback off trimspool on trimout on 
set pagesize 2000 linesize 1000

set heading off
--=========================================================

spool 5-backup.xml

select '<DB_HEALTH_CHECK_DATA versoin="'|| :v_dumpver || '">' ||  chr(10)||
       '<DATABASE type="Oracle">'   ||  chr(10)||
       '  <BACKUP>' from dual;
select /*+ rule */ '    <HC_BACKUP_IN24HOUR  v="' ||count(*)||'"/>' from v\$rman_status
    where start_time > sysdate-1
    and operation='BACKUP';
select /*+ rule */ '    <HC_BACKUP_DB_WEEKLY_MIN  v="' ||round(min(output_bytes)/1024/1024/1024)||' GB"/>' from v\$rman_status
    where start_time > sysdate-10
    and operation='BACKUP' and object_type like 'DB%';
select /*+ rule */ '    <HC_BACKUP_DB_WEEKLY_MAX  v="' ||round(max(output_bytes)/1024/1024/1024)||' GB"/>' from v\$rman_status
    where start_time > sysdate-10
    and operation='BACKUP' and object_type like 'DB%';
select /*+ rule */ '    <HC_BACKUP_ARCH_DAILY_MIN  v="' ||round(min(sum(output_bytes))/1024/1024)||' MB"/>' from v\$rman_status
    where start_time > sysdate-5
    and operation='BACKUP' and object_type like 'ARCHIVELOG%'
    group by trunc(start_time,'dd');
select /*+ rule */ '    <HC_BACKUP_ARCH_DAILY_MAX  v="' ||round(max(sum(output_bytes))/1024/1024)||' MB"/>' from v\$rman_status
    where start_time > sysdate-5
    and operation='BACKUP' and object_type like 'ARCHIVELOG%'
    group by trunc(start_time,'dd');


set heading on
col X_X for a3
col operation for a8
col status for a20
col dura for 999999
col input_bytes for 999,999,999,999,999
col output_bytes for 999,999,999,999,999
prompt <HC_BACKUP_DB>
select * from (select /*+ rule */ '   ' X_X, object_type, start_time, round((end_time-start_time) *86400) dura, input_bytes, 
    output_bytes, substr(status,1,18) status, output_device_type  from v\$rman_status
    where start_time > sysdate-10
    and operation='BACKUP' and object_type like 'DB%' order by start_time desc
) where rownum <=10
order by output_device_type, start_time;
prompt </HC_BACKUP_DB>

prompt <HC_BACKUP_ARCH>
select * from (select /*+ rule */ '   ' X_X, object_type, start_time, round((end_time-start_time) *86400) dura, input_bytes, 
    output_bytes, substr(status,1,18) status, output_device_type from v\$rman_status
    where start_time > sysdate-10
    and operation='BACKUP' and object_type like 'ARCHIVELOG%' order by start_time desc
) where rownum <=10
order by output_device_type, start_time;
prompt </HC_BACKUP_ARCH>

prompt <HC_BACKUP_FAILED>
select * from (select /*+ rule */ '   ' X_X, object_type, start_time, end_time, input_bytes, 
    output_bytes, substr(status,1,18) status from v\$rman_status
    where start_time > sysdate-10
    and operation='BACKUP' and status='FAILED' order by start_time desc
) where rownum <=5;
prompt </HC_BACKUP_FAILED>



set heading off
select '  </BACKUP>'   ||  chr(10)||
       '</DATABASE>'     ||  chr(10)||
       '</DB_HEALTH_CHECK_DATA>'  from dual;

spool off
--exit
EOF
