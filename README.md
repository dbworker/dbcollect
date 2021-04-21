# dbcollect
`dbcollect` help collecting database health related information, which is foundation for db health check.
Later these information will be processed by [dbtools](https://github.com/dbworker/dbtools).

Database health check is a routine task for DBA. Usually, for each database DBA have to run several commands to collect many info, after that write many health check reports(.doc) one-by-one manually.

Now, these tools help doing most of foundation work in health check:
- [dbcollect](https://github.com/dbworker/dbcollect) help collecting database info from many v$_* views, alert log, etc.
- [dbtools](https://github.com/dbworker/dbtools) as a vscode's extension, help exporting many health check reports automatically, just on one click.

**But remember that this tool is not a AI, it can't judge a database's status is OK or not, which is still DBA's duty.**

Currently dbcollect support Linux + Oracle. In future, it will support more platform(AIX, SunOS), and more db type(MySQL, Redis), ...
# How to use dbcollect

Clone dbcollect.git to you pc, then upload to database host(currently Linux) with 'oracle' user.

Go to host's dbcollect folder, then
- (1) Firstly set correct configuration in `config/xxx.toml` file, pls refer to example toml.
- (2) If you run many databases in one host, repeat step 1, one db by one toml file.
- (3) At dbcollect directory, run shell command
```
cd /path/to/dbcollect
sh hccdump.sh
```
If everything ok, after running you will get packed output file `*.tar.gz` in `data/` directory.

(Later you will download *.gz to your pc, unzip it, and open `dbtools` to process it.)

# dbcollect tree view
```
-dbcollect/
|----config/
|    |----*.toml      # database info
|----data/
|    |----*.tar.gz.   # script output result, will used by dbtools to export doc.
|----dump.log         # running log.
|----hccdump.sh       # main script to collect db info
|----script/
|    |----dump_*      # child scripts called by hccdump.sh
|----tomb/
|    |----data2021XXXXXXXX/  # old data move to here, content same to *.tar.gz
|    |----data2021XXXXXXZZ/
|    |    |----ERP-DB/
|    |    |    |----1-host.xml      # host info
|    |    |    |----2-database.xml  # db info
|    |    |    |...
|    |    |    |----attachment/
|    |    |    |    |----alert_sid.log
|    |    |    |    |----awr_2021XXXXXXXX.txt
|    |    |    |    |----config.toml  # content same to config/*.toml, used by dbtools

```

