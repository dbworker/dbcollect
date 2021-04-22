#**********************************************************
# create oracle AWR report.
# time range[now-2.5h, now]
# @input :
#     2-database.xml
# @output:
#     awr.html, awr.txt
#      2-database.xml
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

sed '/^$/d;s/ //g' awr.tmp > sed1.tmp
mv sed1.tmp awr.tmp
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
sed  "/<\/DATABASE>/d" 2-database.xml > sed1.tmp
sed  "/<\/DB_HEALTH_CHECK_DATA>/d" sed1.tmp > 2-database.xml


# AWR report special char
# replace '<' and '>', which will confuse XML Parser?
# char '^L' (0x0C, formfeed, '\f'), not allowed by XML Parser
mAwrFile=`tail -1 awrauto.tmp`
sed  's/\x0c/\x0a/g'  "$mAwrFile" > sed1.tmp
sed  's/>/)/g;s/</(/g' sed1.tmp > "$mAwrFile"

ECHO()
{
    echo "$1" | tee -a 2-database.xml
}

ECHO_M()
{
    echo "$1" |awk '{printf "    %s\n",$0}' | tee -a 2-database.xml
}

# AIX not support grep -A option
GREP_A()
{
case `uname` in
AIX)
    # only return first match
    mTmp=`grep -n "$2" $3 | head -1 | awk -F: '{print $1}'`
    mTmp=` expr $mTmp `
    if [ "$mTmp" -gt 0 ]; then
        mEnd=`expr $mTmp + $1 - 1 `
        head -"$mEnd" "$mAwrFile" | tail -"$1" | awk '{printf "    %s\n",$0}' | tee -a 2-database.xml
    fi
;;
*)
    # maybe multi match
    mTmp=`grep -A $1 "$2"  $3`
    echo "$mTmp" |awk '{printf "    %s\n",$0}' | tee -a 2-database.xml
;;
esac
}


ECHO   ""
ECHO   "  <AWR>"
ECHO   "    <HC_AWR_HEAD>"
GREP_A      4 "^Begin Snap" "$mAwrFile"
ECHO   "    </HC_AWR_HEAD>"
ECHO   ""
ECHO   "    <HC_AWR_PROFILE>"
GREP_A      22 "^Load Profile" "$mAwrFile"
ECHO   "    </HC_AWR_PROFILE>"

ECHO   ""
ECHO   "    <HC_AWR_TOPEVENTS>"
GREP_A      15 "^Top.*Events" "$mAwrFile"
ECHO   "    </HC_AWR_TOPEVENTS>"

ECHO   ""
ECHO   "    <HC_AWR_TBS_IO>"
GREP_A      20 "^Tablespace IO Stats" "$mAwrFile"
ECHO   "    </HC_AWR_TBS_IO>"

ECHO   ""
ECHO   "    <HC_AWR_TABLESCAN>"
ECHO_M      "`grep  \"^table \" $mAwrFile`"
ECHO   "    </HC_AWR_TABLESCAN>"

ECHO   ""
ECHO   "    <HC_AWR_TOP_GETS>"
GREP_A      30 "^SQL ordered by Gets" "$mAwrFile"
ECHO   "    </HC_AWR_TOP_GETS>"

ECHO   "  </AWR>"

ECHO "</DATABASE>"
ECHO "</DB_HEALTH_CHECK_DATA>"




