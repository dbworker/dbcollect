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
mVersion="0.3.2"
mRelease="20220930"

# for safety, only run hccdump.sh in install directory
if [ "$0" != "hccdump.sh"  ]; then
    echo "usage:"
    echo "    cd /path/to/dbcollect"
    echo "    sh hccdump.sh"
    echo "don't use abosolute path or relative path! pls cd to install path."
    exit -1
fi

mToolPath=`pwd`

# some charset/locale will ruin shell output, such as `uptime` on zh_CN
export LANG=en_US.UTF-8

# 'data/' IS WORKING PATH AND SHOULD NOT CD TO OTHER PATH !!!
# in data/ path, 
#   .xml & .log is result file, should move to xxdb/
#   .tmp content is volatile (change many times). 
#   .out is also temp but static after created.
# dir tree as:
# -data/
# |----xxdb1/
# |    |----1-host.xml
# |    |----2-database.xml
# |    |----...(.xml)
# |    |----attachment/
# |    |    |----alert_sid.log
# |    |    |----config.toml
# |    |    |----awr_xxx.html
# |----xxxdb2/
# |    |----...
mkdir -p data tomb
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
    # pseudo column head 'X_X' and '---'' should be cleaned
    sed  "/^$/d;s/^X_X/   /g;s/^---/   /g"       $1 > sed1.tmp
    # @@_@@ is segment flag, and pad space before '<HC'
    sed  "s/^@@_@@//g;s/^<HC/    <HC/g"  sed1.tmp > sed2.tmp
    # lines create by 'prompt <x>' should pre-padding space
    sed  's/^<\/HC/    <\/HC/g'          sed2.tmp > sed1.tmp
    
    mv sed1.tmp  $1
}

# in config toml, maybe exist some evil char [ / \ space ; * ~ < > & | $ `]
# @param cfgFile
FilterEvilChar()
{
    sed  's/\///g;s/\\//g;s/ //g;s/\;//g'      $1 > sed1.tmp
    sed  's/\*//g;s/[~<>&]//g'           sed1.tmp > sed2.tmp
    sed  's/|//g;s/\$//g;s/`//g'         sed2.tmp > sed1.tmp
    mv sed1.tmp  $1
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

# save default ORACLE_SID
mDefaultSID=$ORACLE_SID

# non-PDB sid is case-sensitive, login with 'sqlplus / as sysdba'.
# PDB sid use uppercase(capital),login CDB then turn to PDB.
# TODO: many CDBs on a host? too complicated case.
ps -ef|grep ora_smon_|grep -v grep |awk '{print $NF}'| awk -F_ '{print $NF}' > sidlist.tmp
sqlplus -S "/ as sysdba" << EOF
    set echo off feedback off trimspool on trimout on
    set heading off
    spool pdblist.tmp
    col pdb_name for a20
    select pdb_name from dba_pdbs;
    spool off
EOF
sed '/^$/d;s/ //g' pdblist.tmp > sed1.tmp
mv sed1.tmp pdblist.tmp

#######################################
# foreach xxx.toml in config/:
#     if SID in local SIDs
#         dump x database info
# if many db use same SID, such as 'orcl':
#     orcl will dump many times

ls $mToolPath/config/*.toml > cfg.out
mTmp=`cat cfg.out|wc -l`
mDbCount=` expr $mTmp `
mDbIndex=1
while [ $mDbIndex -le $mDbCount ]
do

mCfgFileName=`head -$mDbIndex cfg.out|tail -1`

# is valid sid/pdb name?
mIsPDB=0
mSid=`grep -i ORACLE_SID $mCfgFileName|sed 's/ORACLE_SID//g;s/[= "]//g'`
# to fully match, distinguish crm / crmdb
mTmp=`awk -v sid="$mSid" '{if($0 == sid) print $0}' sidlist.tmp|wc -l`

# on AIX, wc -l will return '    1', so turn to number
mTmp=`expr $mTmp`
if [ "$mTmp" -eq 1 ]; then
    export ORACLE_SID="$mSid"
else
    # maybe a PDB, turn sid to uppercase
    mSid=`echo $mSid| tr 'a-z' 'A-Z'`
    mTmp=`awk -v sid="$mSid" '{if($0 == sid) print $0}' pdblist.tmp|wc -l`
    mTmp=`expr $mTmp`
    if [ "$mTmp" -eq 1 ]; then
        mIsPDB=1
    else
        mDbIndex=` expr $mDbIndex + 1 `
        continue;
    fi
fi

# get db alias string and filter special char
grep db_alias "$mCfgFileName" > safe.tmp
sed 's/db_alias//g;s/[=" ]//g' safe.tmp > sed1.tmp
sed "s/'//g" sed1.tmp > safe.tmp
FilterEvilChar safe.tmp
mDbAlias=`head -1 safe.tmp`
mNameLen=`expr length "$mDbAlias"`
if [ $mNameLen -gt 60 ]; then
    echo ""
    WLOG "[$0][error] db_alias ($mDbAlias) too long in .toml, $0 exit."
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
    # dump db/sec
    if [ $mIsPDB -eq 0 ]; then
        sqlplus -S "/ as sysdba" << EOF
        @../script/dump_db_oracle_inst.sql "$mVersion" "NO" ""
        @../script/dump_db_oracle_sec.sql  "$mVersion"

        @../script/get_db_oracle_misc.sql
        --exit
EOF
    else
        sqlplus -S "/ as sysdba" << EOF
        alter session set container=$mSid;
        @../script/dump_db_oracle_inst.sql "$mVersion" "YES" $mSid
        @../script/dump_db_oracle_sec.sql  "$mVersion"

        @../script/get_db_oracle_misc.sql
        --exit
EOF
    fi

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
    export ORACLE_SID=$mDefaultSID
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

# if no *.gz then mv will print boring message
mTmp=`ls *.tar.gz|wc -l`
mTmp=`expr $mTmp`
if [ "$mTmp" -gt 0 ]; then
    mv *.tar.gz data/
fi

# seek last start pos
mPos=`grep -n " script started" dump.log|awk  -F: '{print $1}' | tail -1`
mTmp=`cat dump.log|wc -l`
mTmp=`expr $mTmp - $mPos `
mTmp=`expr $mTmp + 1 `
echo ""
echo "******** $0 running summary ********"
tail -$mTmp dump.log
