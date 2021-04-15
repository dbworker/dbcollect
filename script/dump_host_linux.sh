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
    echo "$1" |awk '{printf "    %s\n",$0}' |tee -a $mHostDump
}

#####################################################
#clear, and avoid UTF-BOM
echo "" > $mHostDump

echo   "<DB_HEALTH_CHECK_DATA versoin=\"$mVersion\">" | tee -a $mHostDump
echo   "<HOST type=\"`uname`\">" | tee -a $mHostDump
ECHO   "  <SOFTWARE>"
ECHO_C "    <HC_HOST_NAME    v=" `hostname`
ECHO_C "    <HC_OS_UNAME    v=" `uname`
ECHO_C "    <HC_OS_VERSION   v="
ECHO_C "    <HC_EXEC_DATE   v=" `date +'%Y-%m-%d'`

ECHO   "  </SOFTWARE>"
ECHO

ECHO   "  <HARDWARE>"
ECHO_C "    <HC_OS_PLATFORM  v=" `uname -i`
ECHO_C "    <HC_CPU_COUNT    v=" `grep processor /proc/cpuinfo|wc -l`
ECHO_C "    <HC_MEMORY_SIZE  v=" `grep MemTotal  /proc/meminfo|awk '{printf "%d", int(int($(NF-1))/1048576)}'`
ECHO_C "    <HC_SWAP_SIZE    v=" `grep SwapTotal /proc/meminfo|awk '{printf "%d", int(int($(NF-1))/1048576)}'`
ECHO   "    <HC_OS_DF>"
ECHO_M      "`df -m 2>/dev/null|grep %`"
ECHO   "    </HC_OS_DF>"
ECHO   "    <HC_OS_MEMFREE>"
ECHO_M      "`free -m`"
ECHO   "    </HC_OS_MEMFREE>"

ECHO   "  </HARDWARE>"
ECHO

ECHO   "  <PERFORMANCE>"
ECHO   "    <HC_OS_VMSTAT>"
ECHO_M      "`vmstat 1 5`"
ECHO   "    </HC_OS_VMSTAT>"
ECHO

ECHO   "    <HC_OS_IOSTAT>"
ECHO_M      "`iostat 1 1`"
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

ECHO "</HOST>"
ECHO "</DB_HEALTH_CHECK_DATA>"