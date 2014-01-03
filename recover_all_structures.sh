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


find /var/lib/mysql-theaim -type d  -not -name "mysql" -not -name "performance_schema" -mindepth 1 | sed "s#$ORIG_DB_PATH/##g" | grep -vE '^$' |sort | grep -v bonami | while read db
do
	echo "Doing $db"

	reset_mysql

        mysql -e "create database $db"

	find $ORIG_DB_PATH/$db/ -iname '*.ibd' | sed "s#$ORIG_DB_PATH/##g" | sed 's#/# #' | sort | grep -v bonami | while read junk ibdtable
	do
	        table=`basename $ibdtable .ibd`

        	mysql -e "create table $table (id int) engine=innodb" $db
	done

        stop_mysql

        find $ORIG_DB_PATH/$db/ -iname '*.ibd' | sed "s#$ORIG_DB_PATH/##g" | sed 's#/# #' | sort | grep -v bonami | while read junk ibdtable
        do
                table=`basename $ibdtable .ibd`

        	cp -v $ORIG_DB_PATH/$db/$table.frm /var/lib/mysql/$db/$table.frm
        done

	start_recover_mysql

        mkdir -p $TARGET/structure/$db

        find $ORIG_DB_PATH/$db/ -iname '*.ibd' | sed "s#$ORIG_DB_PATH/##g" | sed 's#/# #' | sort | grep -v bonami | while read junk ibdtable
        do
                table=`basename $ibdtable .ibd`

	        mysqldump -d $db $table > $TARGET/structure/$db/$table.sql

        	grep -qi "create table" $TARGET/structure/$db/$table.sql
        	if [ $? -ne 0 ]
        	then
                	echo "Dump of structure FAILED for $db $table !!!" | tee -a $LOG
        	fi

        done
done

