Will try to recover all innodb-tables from a crashed/corrupt database. 

As it helped me, and I assume other might be in the same situation, I've made it available for anyone to use.

## Needed

  * innodb file per table setting must have been on!
  * Percona data recovery tool for innodb (download and compile - gives ibdconnect and innodbchecksum)
  * Broken dataset, structured as a normal mysql fs layout
  * A clean, empty mysql setup (I used percona mysql 5.5 on debian wheezy)

## Usage 

Look at the scripts, and adjust for your environment. The logic isn't hard, it just needs the right commands to do a certain action. This was used to recover about 7000 tables, summing to about 10 GB of data.

I didn't invent this, nor did I discover the needed steps. It is based on own experience, and logic found on other forums, blogs and github projects. None of them matched my situation, so I just hacked this together. 

There are three scripts:

  * recover_all-slow.sh - the first version, recovers metadata and data one by one, making it slow
  * recover_all_structures.sh - recovering all the structures, database per database, without restarting mysql for each table. This speeds up the process a lot
  * recover_all_data.sh - after all the structures are recovered, you can try and dump the data with this script, table per table. This takes a long time.

I'd suggest you use the structures and data scripts, and not the slow variant. It is only included as a reference.

## Links

  * https://launchpad.net/percona-data-recovery-tool-for-innodb
  * https://github.com/piotrze/ibd_recovery
  * http://www.chriscalender.com/?p=28
  * https://github.com/daviesalex/daviesalex/blob/master/mysql/restore-innodb-data-from-ibd-and-frm-only.sh
