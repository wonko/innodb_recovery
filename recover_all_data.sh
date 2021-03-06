#!/bin/bash

function reset_mysql
{
	/etc/init.d/mysql stop
	killall -9 mysqld mysqld_safe
	rm /etc/mysql/conf.d/innodb_force_recover.cnf
	rm /var/lib/mysql/ib* 
	find /var/lib/mysql -type d -not -name "mysql" -not -name "performance_schema" -exec rm -vRf {} \;
	/etc/init.d/mysql start
	sleep 2
}

function start_recover_mysql
{
        echo "[mysqld]" > /etc/mysql/conf.d/innodb_force_recover.cnf
        echo "innodb_force_recovery=6" >> /etc/mysql/conf.d/innodb_force_recover.cnf

	/etc/init.d/mysql start
	sleep 2
}

function start_mysql
{
	/etc/init.d/mysql start
	sleep 2
}

function stop_mysql
{
	/etc/init.d/mysql stop
}

ORIG_DB_PATH="/var/lib/mysql-broken"
TARGET=/root/recovery/
LOG=/root/recovery/log

echo "Starting at "  `date` | tee -a $LOG

START=`date +%s`
COUNTER=0

find $ORIG_DB_PATH -iname '*.ibd' | sed "s#$ORIG_DB_PATH/##g" | sed 's#/# #' | sort | while read db ibdtable
do
	table=`basename $ibdtable .ibd`
	echo "Working for $db / $table" | tee -a $LOG

	if [ -e $TARGET/data/$db/$table.sql ]
	then
		echo "Skipping, already exists: $TARGET/data/$db/$table.sql" | tee -a $LOG
		continue
	fi

        COUNTER=$[$COUNTER +1]
	
	reset_mysql

        mysql -e "create database $db"
	mysql $db < $TARGET/structure/$db/$table.sql
	
	stop_mysql

        cp -v $ORIG_DB_PATH/$db/$table.ibd /var/lib/mysql/$db/$table.ibd

	/root/percona-data-recovery-tool-for-innodb-0.5/ibdconnect -o /var/lib/mysql/ibdata1 -f /var/lib/mysql/$db/$table.ibd -d $db -t $table

        if [ $? -ne 0 ]
        then
                echo "ibdconnect FAILED for $db $table !!!" | tee -a $LOG
                continue
        fi

	/root/percona-data-recovery-tool-for-innodb-0.5/innochecksum -f /var/lib/mysql/ibdata1 
	/root/percona-data-recovery-tool-for-innodb-0.5/innochecksum -f /var/lib/mysql/ibdata1 
	/root/percona-data-recovery-tool-for-innodb-0.5/innochecksum -f /var/lib/mysql/ibdata1 

        if [ $? -ne 0 ]
        then
                echo "innochecksum FAILED for $db $table !!!" | tee -a $LOG
                continue
        fi

	start_recover_mysql

	mkdir -p $TARGET/data/$db
	mysqldump -n $db $table > $TARGET/data/$db/$table.sql

        if [ $? -eq 0 ]
        then    
		echo "SUCCESS for $db $table :-)" | tee -a $LOG
	else
		echo "dump FAILED for $db $table !!!" | tee -a $LOG
        fi

	NOW=`date +%s`
	echo "Processed $COUNTER tables, " $[($NOW - $START) / $COUNTER] "s per table" 
done
