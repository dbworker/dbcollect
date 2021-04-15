
#**********************************************************
# process different log time format
# 
# @input: misc.out, alert_0.tmp (800000 rows)
# @output: date.tmp (pos of log time wanted)
#**********************************************************

mYearOfLastMon=`head -3 misc.out |tail -1`
mLastMonAbbr=`head -4 misc.out   |tail -1`
mLastMonNum=`head -5 misc.out    |tail -1`

mUniLogTS=`head -6 misc.out      |tail -1`
mUniLogTS=`expr "$mUniLogTS" `

mCurYear=`date +"%Y"`
mCurMonAbbr=`date +"%m"`
mCurMonNum=`date +"%d"`

# alert log time have two format
# normal format:
#   Tue Jan 19 02:14:11 2021
# uniform format:
#   2021-01-15T00:55:14.850202-05:00

NormalLogTS()
{
    grep "$mYearOfLastMon$" alert_0.tmp | grep " $mLastMonAbbr " > date.tmp
    mMatchCount=`cat date.tmp|wc -l`

    # if not exist, search current month date string
    if [ "$mMatchCount" == "0" ]; then
        grep "$mCurYear$" alert_0.tmp | grep " $mCurMonAbbr " > date.tmp
    fi
}

UnifromLogTS()
{
    grep "^$mYearOfLastMon-$mLastMonNum-" alert_0.tmp  > date.tmp
    mMatchCount=`cat date.tmp|wc -l`

    # if not exist, search current month date string
    if [ "$mMatchCount" == "0" ]; then
        grep "^$mCurYear-$mCurMonNum-" alert_0.tmp  > date.tmp
    fi
}


# search month date string
if [ "$mUniLogTS" -eq 0 ]; then
    NormalLogTS
else
    UnifromLogTS
fi
