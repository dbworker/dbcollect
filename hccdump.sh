#**********************************************************
# hccdump is a util to export host & database info.
# it call real dump-scripts on different os/db type:
#     script/dump_db_*
#     script/dump_host_*
#
# 'config/xxdb.toml' should exists before execute.
#
#  FOR SAFETY, ONLY RUN 'hccdump.sh' IN INSTALL DIRECTORY.
#  ONLY USE `rm` WITH A SPECIFIED FILE.
#**********************************************************
mVersion="0.2"
mRelease="20210415"

# for safety, only run hccdump.sh in install directory
if [ "$0" != "hccdump.sh"  ]; then
    echo "usage:"
    echo "    cd /path/to/dbtutil"
    echo "    sh hccdump.sh"
    echo "don't use abosolute path or relative path! pls cd to install path."
    exit -1
fi

mToolPath=`pwd`

# 'data/' IS WORKING PATH AND SHOULD NOT CD TO OTHER PATH !!!
# in data/ path, 
#   .xml / .log is result file, should move to xxdb/
#   .tmp content is volatile (change many times). 
#   .out is also temp but static after created.
# dir tree as:
# -data/
# |----xxdb1/
# |    |----1-host.xml
# |    |----2-database.xml
# |    |----...(.xml)
# |    |----attachment/
# |    |    |----alert.log
# |    |    |----config.toml
# |    |    |----awr_xxx.html
# |----xxxdb2/
# |    |----...
mkdir -p data
cd data

WLOG()
{
    echo "[`date +'%Y-%m-%d %H:%M:%S'`]$1"| tee -a ../dump.log
}

WLOG ""
WLOG "[$0][info] script started."

# beautify oracle xml data by indent space
# @param xmlFile
FormatOracleXml()
{
    # column '   ' made heading ^'' and should be cleaned
    sed -i "/^$/d;s/^''/  /g;s/^---/   /g" $1
    # @@_@@ is segment flag, and pad space before '<HC'
    sed -i "s/^@@_@@//g;s/^<HC/    <HC/g"  $1
    sed -i 's/^<\/HC/    <\/HC/g'          $1
}

# in config toml, maybe exist some evil char [ / \ space ; * ~ < > | $ `]
# @param cfgFile
FilterEvilChar()
{
    sed -i 's/\///g;s/\\//g;s/ //g;s/\;//g' $1
    sed -i 's/\*//g;s/~//g; s/<//g;s/>//g' $1
    sed -i 's/|//g;s/\$//g;s/`//g' $1
}

#######################################
# dump host info
case `uname` in
Linux)
    # scritp create 1-host
    sh $mToolPath/script/dump_host_linux.sh "$mVersion"
;;
AIX)
    sh $mToolPath/script/dump_host_aix.sh   "$mVersion"
;;
*)
    sh $mToolPath/script/dump_host_unix.sh  "$mVersion"
;;
esac

#######################################
# foreach xxx.toml in config/:
#     dump x database info

ls $mToolPath/config/*.toml > cfg.out
mTmp=`cat cfg.out|wc -l`
mDbCount=` expr $mTmp `
mDbIndex=1
while [ $mDbIndex -le $mDbCount ]
do

mCfgFileName=`head -$mDbIndex cfg.out|tail -1`

# get db alias string and filter special char
grep db_alias "$mCfgFileName" > safe.tmp
sed -i 's/db_alias//g;s/=//g;s/"//g' safe.tmp
sed -i "s/'//g" safe.tmp
FilterEvilChar safe.tmp
mDbAlias=`head -1 safe.tmp`
mNameLen=`expr length "$mDbAlias"`
if [ $mNameLen -gt 20 ]; then
    echo ""
    WLOG "[$0][error] db_alias too long in .toml, $0 exit."
    exit -1
fi
if [ $mNameLen -eq 0 ]; then
    echo ""
    WLOG "[$0][error] db_alias not exist or invalid in .toml, $0 exit."
    exit -1
fi

WLOG "[$0][info] dumping $mDbAlias."

# then create db_alias/ folder
mkdir -p $mDbAlias/attachment
cp 1-host $mDbAlias/1-host.xml

# dispatch to child-scripts by db_type
mDbType=`grep db_type "$mCfgFileName" | sed 's/db_type//g;s/=//g;s/"//g'|tr 'a-z' 'A-Z'`
case "$mDbType" in
ORACLE)
    # set env
    mSid=`grep -i ORACLE_SID $mCfgFileName|sed 's/ORACLE_SID//g;s/=//g;s/"//g'`
    export ORACLE_SID="$mSid"

    # dump db/sec
    sqlplus -S "/ as sysdba" << EOF
    @../script/dump_db_oracle_inst.sql "$mVersion"
    @../script/dump_db_oracle_sec.sql  "$mVersion"

    @../script/get_db_oracle_misc.sql
    --exit
EOF
    # indent some space
    FormatOracleXml 2-database.xml
    FormatOracleXml 3-security.xml
 
    # dump alert log
    # @input misc.out
    # @output alert_sid.log
    sh ../script/dump_db_oracle_soft.sh "$mVersion"
    mv alert*.log $mDbAlias/attachment/

    # dump AWR (text&html), maybe no awr_* created
    sh ../script/dump_db_oracle_awr.sh
    mv awr_* $mDbAlias/attachment/

    # dump backup info, if NOARCHIVELOG then no file created
    sh ../script/dump_db_oracle_rman.sh "$mVersion"
    if [ -e 5-backup.xml ]; then
        FormatOracleXml 5-backup.xml
    fi

    # pack output, TOML rename to config.toml (need by dbtools)
    mv *.xml $mDbAlias/
    cp $mCfgFileName $mDbAlias/attachment/config.toml
    tar cvf  $mDbAlias.tar $mDbAlias
    gzip -f $mDbAlias.tar
    mv $mDbAlias.tar.gz ../

    #just leave *.tmp
;;
MYSQL)
    sh hccdump_db_mysql.sh
;;
esac

mDbIndex=` expr $mDbIndex + 1 `
done

WLOG "[$0][info] script end."

# old data/ move to tomb, and create a new data/
cd ../
mTmp=`date +"%Y%m%d%H%M%S"`
mv data tomb/"data$mTmp"
mkdir data
mv *.gz data/

# seek last start pos
mPos=`grep -n " script started" dump.log|awk  -F ':' 'END{print $1}'`
mTmp=`cat dump.log|wc -l`
mTmp=`expr "$mTmp" - "$mPos" + 1 `
echo ""
echo "******** $0 running summary ********"
tail -$mTmp dump.log
