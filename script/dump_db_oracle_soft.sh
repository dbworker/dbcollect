
#**********************************************************
# oracle soft keep many info in os, such as:
#   alert log, opatch info, crs stat, etc.
#
# dump alert log only that happened from early last month.
# brute force algorithm: tail -800000 log then find matched.
# misc.out created by get_db_oracle_misc.sql
# 
# @input: misc.out(date, alert file path)
# @output: alert_sid.log, 4-runlog.xml
#**********************************************************

WLOG()
{
    echo "[`date +'%Y-%m-%d %H:%M:%S'`]$1"| tee -a ../dump.log
}

sed  '/^$/d;s/ //g' misc.out > sed1.tmp
mv sed1.tmp  misc.out
mAlertPath=`head  -1 misc.out |tail -1`
mAlertName=`head  -2 misc.out |tail -1`

tail -800000 "$mAlertPath/$mAlertName" > alert_0.tmp

# process different log time format, output matched time lines
# @input alert_0.tmp
# @output date.tmp
sh ../script/sub_readalert.sh

# if not matched, return some lastest log
mMatchCount=`cat date.tmp|wc -l`
mMatchCount=`expr $mMatchCount`
if [ "$mMatchCount" -eq 0 ]; then
    tail -50000 alert_0.tmp > alert_1.tmp
    WLOG "[$0][info] filter alert log content fail, return last 50000 lines."
else
    # use date.tmp's first date to locate line in alert.log
    mFirstDate=`head -1 date.tmp`
    grep -n "$mFirstDate" alert_0.tmp |head -1 > date.tmp
    mPos=`awk -F: '{print $1}' date.tmp`
    mAll=`cat alert_0.tmp|wc -l`
    mPos=`expr $mAll - $mPos `
    mPos=`expr $mPos + 1 `
    if [ "$mPos" -gt 50000 ]; then
        tail -50000 alert_0.tmp > alert_1.tmp
    else
        tail -$mPos alert_0.tmp > alert_1.tmp
    fi
fi
# filter normal info such as redo swith, along with date line
# @input alert_1.tmp
# @output alert_1.tmp
sh ../script/sub_filteralert.sh
mv alert_1.tmp "$mAlertName"

rm alert_0.tmp

#####################################################
# opatch info
mSoftInfo="4-runlog.xml"

# clear, and avoid UTF-BOM
echo "" > $mSoftInfo

ECHO()
{
    echo "$1" | tee -a $mSoftInfo
}
ECHO_C()
{
    echo "$1\"$2\"/>" | tee -a $mSoftInfo
}
ECHO_M()
{
    echo "$1" |sed 's/\&/\&amp\;/g' |sed 's/</\&lt\;/g;' |awk '{printf "    %s\n",$0}' |tee -a $mSoftInfo
}

echo   "<DB_HEALTH_CHECK_DATA versoin=\"$1\">" | tee -a $mSoftInfo
echo   "<DATABASE type=\"Oracle\">" | tee -a $mSoftInfo


lsnrPath=`lsnrctl status|grep "Listener Log File" |awk '{print $NF}' |sed 's/log.xml//g'`
lsnrCnt=`ls $lsnrPath|wc -l`
lsnrCnt=`expr $lsnrCnt `
ECHO_C "    <HC_LSNR_TRAIL_COUNT v=" "$lsnrCnt"

lsnrSize=`echo "$lsnrPath"listener.log | sed 's/alert/trace/g'| xargs ls -l | awk '{print $5}'`
ECHO_C "    <HC_LSNR_LOG_SIZEM   v=" `expr $lsnrSize / 1048576 `


mIsRAC=`head  -8 misc.out |tail -1`
mDbVer=`head  -9 misc.out |tail -1`
mDbVer=`expr $mDbVer `

if [ "$mIsRAC" == "YES" ]; then
    grid_bin=`ps -ef|grep ocssd.bin |grep -v grep | awk '{print $NF}'`

    oif_bin=`echo "$grid_bin" | sed 's/ocssd.bin/oifcfg/g'`
    ECHO   ""
    ECHO   "    <HC_CRS_IFCFG>"
    ECHO_M      "`$oif_bin getif`"
    ECHO   "    </HC_CRS_IFCFG>"

    crs_bin=`echo "$grid_bin" | sed 's/ocssd.bin/crsctl/g'`
    ECHO   ""
    ECHO   "    <HC_CRS_STAT>"
    ECHO_M      "`$crs_bin stat res -t`"
    ECHO   "    </HC_CRS_STAT>"

    if [ "$mDbVer" -lt 12 ]; then
        # 11g, crs log in $GRID_HOME/log/
        csstmp=`hostname`/cssd
        grid_home=`ps -ef|grep ocssd.bin |grep -v grep | awk '{print $NF}'`
        csspath=`echo "$grid_home" | sed 's/bin\/ocssd.bin/log/g'`
        csspath=`echo "$csspath"/"$csstmp"`

        ECHO   "    <HC_CRS_OCSSD_ERROR>"
        ECHO_M      "`ls -t $csspath/ocssd* | head | xargs grep 'heartbeat fatal' | tail -50`"
        ECHO   "    </HC_CRS_OCSSD_ERROR>"

        ECHO   "    <HC_CRS_OCSSD_LOG>"
        ECHO_M      "`ls -t $csspath/ocssd* | head -1 |xargs tail -50`"
        ECHO   "    </HC_CRS_OCSSD_LOG>"

    else
        # 12c, crs log in $GRID_BASE/diag
        mTracePath=`lsnrctl status|grep "Listener Log File" |awk '{print $NF}' |sed 's/tnslsnr/ /g'|awk '{print $1}'`
        mTracePath=`echo "$mTracePath"`crs/`hostname`/crs/trace
        
        ECHO   "    <HC_CRS_OCSSD_ERROR>"
        ECHO_M      "`ls -t $mTracePath/ocssd*.trc | head | xargs grep 'heartbeat fatal' | tail -50`"
        ECHO   "    </HC_CRS_OCSSD_ERROR>"

        ECHO   "    <HC_CRS_OCSSD_LOG>"
        ECHO_M      "`ls -t $mTracePath/ocssd*.trc | head -1 |xargs tail -50`"
        ECHO   "    </HC_CRS_OCSSD_LOG>"
    fi
fi

ECHO "</DATABASE>"
ECHO "</DB_HEALTH_CHECK_DATA>"

