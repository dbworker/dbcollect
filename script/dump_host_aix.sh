# called by hccdump.sh
# usage: sh /path/to/script  <version>
mVersion="$1"
mHostDump="1-host"

#basic
ECHO()
{
    echo "$1" | tee -a $mHostDump
}
#with close tag
ECHO_C()
{
    echo "$1\"$2\"/>" | tee -a $mHostDump
}
#multi line with left pad space
ECHO_M()
{
    echo "$1" |sed 's/\&/\&amp\;/g' |sed 's/</\&lt\;/g;' |awk '{printf "    %s\n",$0}' |tee -a $mHostDump
}

mHostname=`hostname`
#####################################################
#clear, and avoid UTF-BOM
echo "" > $mHostDump

echo   "<DB_HEALTH_CHECK_DATA versoin=\"$mVersion\">" | tee -a $mHostDump
echo   "<HOST type=\"`uname`\">" | tee -a $mHostDump
ECHO   "  <SOFTWARE>"
ECHO_C "    <HC_HOST_NAME    v=" "$mHostname"
ECHO_C "    <HC_OS_UNAME     v=" `uname`
ECHO_C "    <HC_OS_VERSION   v=" `oslevel -s`
ECHO_C "    <HC_OS_IPADDR    v=" `grep $mHostname /etc/hosts | grep -v "^#" | head -1 | awk '{print $1}'`
ECHO_C "    <HC_EXEC_DATE    v=" `date +'%Y-%m-%d'`
ECHO_C "    <HC_OS_UPDAYS    v=" `uptime |awk '{print $3}'`
ECHO   "    <HC_OS_KERNEL>"
ECHO_M      "`/usr/sbin/no -a 2>&1 |egrep '(tcp_|udp_)'`"
ECHO   "    </HC_OS_KERNEL>"
ECHO   "  </SOFTWARE>"
ECHO

ECHO   "  <HARDWARE>"
ECHO_C "    <HC_OS_PLATFORM  v=" `uname -p`
ECHO_C "    <HC_CPU_COUNT    v=" `lsdev -Cc processor | wc -l`
ECHO_C "    <HC_MEMORY_SIZE  v=" `prtconf 2>/dev/null | grep "^Memory Size:" |  awk '{printf $3}'`
ECHO_C "    <HC_SWAP_SIZE    v=" `lsps -s | tail -1 | awk '{printf "%s", $1}'`
ECHO_C "    <HC_OS_DF_UMAX   v=" `df -m 2>/dev/null | awk '{printf "%3d\n", $(NF-3)}' | sort -n -r | head -1`
ECHO_C "    <HC_OS_DF_IMAX   v=" `df -m 2>/dev/null | awk '{printf "%3d\n", $(NF-2)}' | sort -n -r | head -1`

ECHO   "    <HC_OS_DF>"
ECHO_M      "`df -m 2>/dev/null|grep %`"
ECHO   "    </HC_OS_DF>"

ECHO   "    <HC_OS_MEMFREE>"
ECHO_M      "`svmon -G`"
ECHO   "    </HC_OS_MEMFREE>"
ECHO   "    <HC_OS_NTP>"
ECHO_M      "`ps -ef|grep ntp|grep -v grep`"
ECHO   "    </HC_OS_NTP>"
ECHO   "    <HC_OS_ULIMIT>"
ECHO_M      "`ulimit -a`"
ECHO   "    </HC_OS_ULIMIT>"

ECHO   "    <HC_OS_MISC>"
ECHO_M      "`prtconf 2>/dev/null | head -25`"
ECHO   "    </HC_OS_MISC>"

ECHO   "  </HARDWARE>"
ECHO

ECHO   "  <PERFORMANCE>"
ECHO   "    <HC_OS_VMSTAT>"
ECHO_M      "`vmstat 1 5`"
ECHO   "    </HC_OS_VMSTAT>"
ECHO

ECHO   "    <HC_OS_IOSTAT>"
ECHO_M      "`iostat -l -D 1 1`"
ECHO   "    </HC_OS_IOSTAT>"
ECHO   "  </PERFORMANCE>"
ECHO

ECHO   "  <NETWORK>"
ECHO
ECHO   "  </NETWORK>"
ECHO
ECHO   "  <STORAGE>"
ECHO
ECHO   "  </STORAGE>"

ECHO
ECHO   "  <HC_OPATCH_LS>"
ECHO_M    "`$ORACLE_HOME/OPatch/opatch lsinventory | grep -v '^    '`"
ECHO   "  </HC_OPATCH_LS>"

ECHO "</HOST>"
ECHO "</DB_HEALTH_CHECK_DATA>"
