#**********************************************************
# filter normal info in alert log, make output thin
# 
# @input: alert_1.tmp
# @output: alert_1.tmp
#**********************************************************

# except awk, sed also can join 2 lines, sed ':a ; N;s/\n/ / ; t a ; ' file

# Filter case 1 - Redo switch
# Tue Jan 19 02:19:24 2021
# Thread 1 advanced to log sequence 746728 (LGWR switch)
#   Current log# 1 seq# 746728 mem# 0: +DATA/ORCL/ONLINELOG/group_1.270.994000595
#   Current log# 1 seq# 746728 mem# 1: +DATA/ORCL/ONLINELOG/group_1.269.994000595
awk 'BEGIN{RS=EOF}{gsub(/\nThread . advanced to /," Thread . advanced to ");print}' alert_1.tmp | grep -v "(LGWR switch)" | grep -v "^  Current log#" > alert_2.tmp


# Filter case 2 - Redo archive
# Tue Jan 19 02:14:41 2021
# Archived Log entry 1415088 added for thread 1 sequence 746725 ID 0x5a588052 dest 1:
awk 'BEGIN{RS=EOF}{gsub(/\nArchived Log entry /," Archived Log entry ");print}' alert_2.tmp | grep -v "Archived Log entry" > alert_1.tmp

# Filter case 3 - Redo to standby
# Mon Feb 08 08:54:38 2021
# LGWR: Standby redo logfile selected for thread 1 sequence 162867 for destination LOG_ARCHIVE_DEST_2
awk 'BEGIN{RS=EOF}{gsub(/\nLGWR: Standby redo logfile selected /," LGWR: Standby redo logfile selected ");print}' alert_1.tmp | grep -v "LGWR: Standby redo logfile selected" > alert_2.tmp

# Filter case 4 - Redo alter
# Mon Feb 08 08:54:49 2021
# ALTER SYSTEM ARCHIVE LOG
awk 'BEGIN{RS=EOF}{gsub(/\nALTER SYSTEM ARCHIVE LOG/," ALTER SYSTEM ARCHIVE LOG");print}' alert_2.tmp | grep -v "ALTER SYSTEM ARCHIVE LOG" > alert_1.tmp

# Filter case 5 - Redo not complete
# Sun Feb 28 23:22:55 2021
# Thread 1 cannot allocate new log, sequence 167165
# Checkpoint not complete
grep -v "cannot allocate new log" alert_1.tmp | awk 'BEGIN{RS=EOF}{gsub(/\nCheckpoint not/," Checkpoint not");print}' > alert_2.tmp

mv alert_2.tmp alert_1.tmp
