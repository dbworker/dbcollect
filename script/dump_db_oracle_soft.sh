
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

sed -i '/^$/d;s/ //g' misc.out
mAlertPath=`head  -1 misc.out |tail -1`
mAlertName=`head  -2 misc.out |tail -1`

tail -800000 "$mAlertPath/$mAlertName" > alert_0.tmp

# process different log time format, output matched time lines
# @input alert_0.tmp
# @output date.tmp
sh ../script/sub_readalert.sh

# if not matched, return some lastest log
mMatchCount=`cat date.tmp|wc -l`
if [ "$mMatchCount" == "0" ]; then
    tail -50000 alert_0.tmp > "$mAlertName"
    WLOG "[$0][info] filter alert log content fail, return last 50000 lines."
else
    # use date.tmp's first date to locate line in alert.log
    mFirstDate=`head -1 date.tmp`
    grep -n "$mFirstDate" alert_0.tmp |head -1 > date.tmp
    mPos=`awk -F ':' '{print $1}' date.tmp`
    mAll=`cat alert_0.tmp|wc -l`
    mPos=` expr "$mAll" - "$mPos" + 1 `
    tail -$mPos alert_0.tmp > alert_1.tmp

    # filter normal info such as redo swith, along with date line
    # @input alert_1.tmp
    # @output alert_1.tmp
    sh ../script/sub_filteralert.sh

    mv alert_1.tmp "$mAlertName"
fi
rm alert_0.tmp

#####################################################
# opatch info
mOpatchInfo="4-runlog.xml"

# clear, and avoid UTF-BOM
echo "" > $mOpatchInfo

ECHO()
{
    echo "$1" | tee -a $mOpatchInfo
}

ECHO_M()
{
    echo "$1" |awk '{printf "    %s\n",$0}' |tee -a $mOpatchInfo
}

echo   "<DB_HEALTH_CHECK_DATA versoin=\"$1\">" | tee -a $mOpatchInfo
echo   "<DATABASE type=\"Oracle\">" | tee -a $mOpatchInfo

ECHO   ""
ECHO   "    <HC_OPATCH_LS>"
ECHO_M      "`$ORACLE_HOME/OPatch/opatch lsinventory`"
ECHO   "    </HC_OPATCH_LS>"

mIsRAC=`head  -8 misc.out |tail -1`

if [ "$mIsRAC" == "YES" ]; then
    ECHO   ""
    ECHO   "    <HC_CRS_IFCFG>"
    ECHO_M      "`oifcfg getif`"
    ECHO   "    </HC_CRS_IFCFG>"

    ECHO   ""
    ECHO   "    <HC_CRS_STAT>"
    ECHO_M      "`crsctl stat res -t`"
    ECHO   "    </HC_CRS_STAT>"
fi

ECHO "</DATABASE>"
ECHO "</DB_HEALTH_CHECK_DATA>"

