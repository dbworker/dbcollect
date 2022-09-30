# 1. dbcollect
`dbcollect` help DBA to collecting database info, which later will be processed by [dbtools](https://marketplace.visualstudio.com/items?itemName=dbworker.dbtools), to auto check db's health and export reports.

Usually, for health-check task, DBA  collecting info, checking info and  writting reports(.doc) for each db manually.

Now, these tools help doing most of foundation work in health check:
- [dbcollect](https://github.com/dbworker/dbcollect) help collecting database info from many v$_* views, alert log, etc.
- [dbtools](https://marketplace.visualstudio.com/items?itemName=dbworker.dbtools) is a vscode's extension, 
  - help exporting many health check reports automatically;
  - use **rule-based check**([dbtools-rule](https://github.com/dbworker/dbtools-rule/blob/main/oracle_rule.ini)), check database's health and show problems on vscode IDE.

For example, dbcollect will dump some data like this
```
<DB_HEALTH_CHECK_DATA versoin="0.3.0">
<DATABASE type="Oracle">
  <INSTANCE>
    <HC_DB_NAME          v="TESTDB"/>
    <HC_DB_ID            v="8810916561"/>
    <HC_DB_VERSION       v="11.2.0.4.0"/>
    ...
```
dbtools use these xml data to check db's health(show in gif):
![iamge](https://gitee.com/dbworker/dbtools-rule/raw/HEAD/dbtools-usage-sample.gif)


Currently dbcollect support Oracle(>= 11g) on (Linux, AIX).

Be a happy DBA: https://www.youtube.com/watch?v=05H3M8m__4o&ab_channel=dbworker

# 2. How to use dbcollect

Download or clone dbcollect.git to you pc, then upload to database host (Linux or AIX) with 'oracle' user.

Open a terminal, login db host as user `oracle`, change to dbcollect folder
```
cd /path/to/dbcollect
```
then
- (1) Firstly change to `config/` directory and modify `*.toml` file, pls refer to example toml.
```
cd config
vi xxx.toml
```

- (2) If you run many instances or pdbs in one host, repeat step 1, one db by one toml file.
```
vi yyy.toml
```

- (3) change to dbcollect directory, run shell command
```
cd ..
sh hccdump.sh
```
If everything ok, after running you will get packed output file `*.tar.gz` in `data/` directory.

(Later you will download *.gz to your pc, unzip it, and open `dbtools` to process it.)

# 3. dbcollect tree view
```
-dbcollect/
|----config/
|    |----*.toml      # database info
|----data/
|    |----aix11g_testrac1.tar.gz  # example, AIX + oracle11g + rac
|    |----lnx19c_cdbrac1.tar.gz   # example, linux + oracle19c + CDB$ROOT
|    |----lnx19c_pdb1.tar.gz      # example, linux + oracle19c + PDB1
|    |
|----dump.log         # dumping log.
|----hccdump.sh       # main script to collect db info
|----script/
|    |----dump_*      # child scripts called by hccdump.sh
|----tomb/
|    |----data2021XXXXXXXXXX/  # old data move to here, content same to *.tar.gz
|    |    |----aix11g_testrac1/
|    |    |    |----1-host.xml      # host info
|    |    |    |----2-database.xml  # db info
|    |    |    |...
|    |    |    |----attachment/
|    |    |    |    |----alert_TESTDB1.log
|    |    |    |    |----awr_2021XXXXXXXX.txt
|    |    |    |    |----config.toml  # content same to config/*.toml, used by dbtools

```

# 4. FAQ

## 4.1 Field meaning in config/*.toml

config/*.toml was used by dbcollect , then packed in dump file and transfer to dbtools.

(1)`customer` and `doctitle` used by dbtools to export doc
- export doc name is in form like  "customer_doctitle.doc"
- doc first page will replace placeholder-tag using : customer, doctitle
- to avoid unrecognizable char(GBK,Japan), should use only ASCII char
```
customer="CMCBANK"
doctitle="TEST1_TESTDB1 Database Health Check Report"  # must be unique, should be meaningful
```


(2) `db_alias` used as folder name by dbcollect to store dump file
- for manual reading, should be meaningful, and only ASCII char
- must be unique in customer's hundreds database
```
db_alias="TESTDB1"   # used as meaningful folder name
                     # must be unique to distinguish from other db
```

(3) `ORACLE_SID` be used to connect to oracle
```
db_type="Oracle"     # used by hccdump to fill in xml
ORACLE_SID="TESTDB1" # used by hccdump to connect to oracle
```

## 4.2 Output filename has unrecognizable char
Recommend use ASCII char in config file *.toml.
Don't use local language character set, such as GBK.


# 5. Known issues

currently v0.3.0 has some fault:
- on PDB, some values are same to CDB$ROOT (see example file lnx19c_pdb1.tar.gz).
- if database has large object number, some queries will slow
    - HC_TABLE_USE_LONG
    - HC_BIG_TABLES  
(you can manually disable related sql on script)


# 6. Future plan

- refine PDB info
- item for flashback, v$recovery_area_usage
- top transaction (top sql already in AWR)

# 7. Release history

**v0.3.2 at 30-Seq-2022**
- add items `HC_SEQ_HIGH_PCTUSED_COUNT` and `HC_HIGH_PCTUSED_SEQS` to monitor sequences whether close to max limit.


**v0.3.1 at 20-Seq-2021**
- add script `hccdump_sun.sh` to support SunOS.


**v0.3.0 at 20-May-2021**
- add more dump item
- in alert file, some unimportanted log was removed ( not valid for oracle12.2's uniform time format ).
- fix issue on v$rman_status ( [issue#1](https://github.com/dbworker/dbcollect/issues/1) )
- fix special char (<, &) on .xml ( [issue#2](https://github.com/dbworker/dbcollect/issues/2) )
- fix dump alert log on AIX
- fix dump crs log


**v0.2.2 at 20-Apr-2021**  
(no formally build release)
