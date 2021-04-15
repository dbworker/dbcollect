#**********************************************************
# create oracle AWR report.
# time range[now-2.5h, now]
#
#**********************************************************

WLOG()
{
    echo "[`date +'%Y-%m-%d %H:%M:%S'`]$1"| tee -a ../dump.log
}

# AWR min/max snap_id within past 2.5 hours, otherwise set -1 and no dump
sqlplus -S "/ as sysdba" << EOF
set echo off feedback off trimspool on trimout on 

variable v_snapcnt number;
variable v_minsnapid number;
variable v_maxsnapid number;
exec :v_minsnapid := -1;
exec :v_maxsnapid := -1;

set heading off
spool awr.tmp

exec select count(snap_id) into :v_snapcnt from dba_hist_snapshot snap, v\$instance inst where snap.instance_number = inst.instance_number  and end_interval_time > sysdate - 2.5/24;

-- should have several snaps, otherwise return -1
exec if :v_snapcnt >1 then select min(snap_id),max(snap_id) into :v_minsnapid,:v_maxsnapid from dba_hist_snapshot snap, v\$instance inst  where snap.instance_number = inst.instance_number  and end_interval_time > sysdate - 2.5/24; end if;
print :v_minsnapid
print :v_maxsnapid

spool off
--exit
EOF

sed -i '/^$/d;s/ //g' awr.tmp
mMinSnapId=`head -1 awr.tmp`
mMaxSnapId=`tail -1 awr.tmp`

mMinSnapId=`expr "$mMinSnapId"`
if [ $mMinSnapId -lt 0 ]; then
    WLOG "[$0][error] create awr report fail, no valid snapshot."
    exit
fi


CreateAWR()
{
    # html/text, 1 day
    echo $1 > awrauto.tmp
    echo 2 >> awrauto.tmp
    echo $mMinSnapId >> awrauto.tmp
    echo $mMaxSnapId >> awrauto.tmp
    echo "awr_`date +'%Y%m%d_%H%M%S'`.$2" >> awrauto.tmp

    sqlplus -S "/ as sysdba" @?/rdbms/admin/awrrpt.sql < awrauto.tmp
}

# text will be insert into hcc-template, html for dba reading

CreateAWR "html" "html"
CreateAWR "text" "txt"

# append some awr info to database.xml, so delete some tag.
sed -i "/<\/DATABASE>/d" 2-database.xml
sed -i "/<\/DB_HEALTH_CHECK_DATA>/d" 2-database.xml


# AWR report special char
# replace '<' and '>', which will confuse XML Parser?
# char '^L' (0x0C, formfeed, '\f'), not allowed by XML Parser
mTmp=`tail -1 awrauto.tmp`
sed -i 's/\x0c/\x0a/g'  "$mTmp"
sed -i 's/>/)/g;s/</(/g' "$mTmp"

ECHO()
{
    echo "$1" | tee -a 2-database.xml
}

ECHO_M()
{
    echo "$1" |awk '{printf "    %s\n",$0}' | tee -a 2-database.xml
}


ECHO   ""
ECHO   "  <AWR>"
ECHO   "    <HC_AWR_HEAD>"
ECHO_M      "`grep -A 4 \"^Begin Snap\" $mTmp`"
ECHO   "    </HC_AWR_HEAD>"
ECHO   ""
ECHO   "    <HC_AWR_PROFILE>"
ECHO_M      "`grep -A 22 \"^Load Profile\" $mTmp`"
ECHO   "    </HC_AWR_PROFILE>"

ECHO   ""
ECHO   "    <HC_AWR_TOPEVENTS>"
ECHO_M      "`grep -A 15 \"^Top.*Events\" $mTmp`"
ECHO   "    </HC_AWR_TOPEVENTS>"

ECHO   ""
ECHO   "    <HC_AWR_TBS_IO>"
ECHO_M      "`grep -A 20 \"Tablespace IO Stats\" $mTmp`"
ECHO   "    </HC_AWR_TBS_IO>"

ECHO   ""
ECHO   "    <HC_AWR_TABLESCAN>"
ECHO_M      "`grep  \"^table \" $mTmp`"
ECHO   "    </HC_AWR_TABLESCAN>"

ECHO   ""
ECHO   "    <HC_AWR_TOP_GETS>"
ECHO_M      "`grep -A 30 -i \"SQL ordered by Gets\" $mTmp`"
ECHO   "    </HC_AWR_TOP_GETS>"

ECHO   "  </AWR>"

ECHO "</DATABASE>"
ECHO "</DB_HEALTH_CHECK_DATA>"




