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
select '    <HC_BACKUP_IN24HOUR  v="' ||count(*)||'"/>' from v\$rman_status
    where start_time > sysdate-1
    and operation='BACKUP';

set heading on
prompt <HC_BACKUP_STAT>
col operation for a8
col status for a20
select '   ',operation, object_type, start_time, end_time, input_bytes, 
    output_bytes, status from v\$rman_status
    where start_time > sysdate-10
    and operation='BACKUP' order by start_time desc;
prompt </HC_BACKUP_STAT>

set heading off
select '  </BACKUP>'   ||  chr(10)||
       '</DATABASE>'     ||  chr(10)||
       '</DB_HEALTH_CHECK_DATA>'  from dual;

spool off
--exit
EOF
