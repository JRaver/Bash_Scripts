#!/bin/bash
HELP () {
    echo "-a Type of Dump [all|one]"
    echo "-d Database name"
    echo "-s Schema Type [y|n]"
    echo "Example 1 Dump DB: ./`basename $0` -d tapi_unreal"
    echo "Example 2 Dump DB with suffix-name: ./`basename $0` -d tapi_unreal -v before_ver"
    echo "Example 3 Dump DB schema: ./`basename $0` -d tapi_unreal -s "
    echo "Example 4 Dump all DBs: ./`basename $0` -a"
    echo "Example 5 Dump all DBs schema: ./`basename $0` -a -s "
}
STOP_REP () {
    if [ $SLAVE -eq 1  ];then
        echo STOP REP on SLAVE >> $DUMP_F_LOG
        psql -c "select pg_xlog_replay_pause();" >> $DUMP_F_LOG
    fi
}
START_REP () {
    if [ $SLAVE -eq 1  ];then
        echo START REP on SLAVE >> $DUMP_F_LOG
        psql -c "select pg_xlog_replay_resume();" >> $DUMP_F_LOG
    fi
}

export LANG="en_US.UTF-8"
H_DIR="db-k-tapi-01"
DUMP_DIR="/media/dump/$H_DIR/backup"
timestamp=`date +%Y.%m.%d_%H.%M`
host=`hostname`
NTYPE="pg_dump"
TYPEDUMP="dump"
PS_SCHEMA=""
SCHEMADUMP=""
SLAVE="0"
SUFFIX=""
if [ $# -eq 0 ];then
    echo "WARNING:  You didn't set any parametrs. Try `basename $0` -h"
    exit 1
fi
while [ $# -gt 0 ]
do
    case "$1" in
        -a) shift 
            NTYPE="pg_dumpall"
            TYPEDUMP="dumpall"
        ;;
        -d) DB=$2
            shift 2
        ;;
        -s) 
            shift 
            PS_SCHEMA="-s"
            SCHEMADUMP="schema"
            DUMP_DIR="/media/dump/$H_DIR/backup/schema"

        ;;
        -p)
            shift 
            SLAVE=1       
        ;;
        -v)
            SUFFIX=$2
            shift 2
        ;;
        -h)
            HELP
            exit 0
        ;;

        *)
            echo "Invalid arguments, Try `basename $0` -h"
            exit 1
        ;;
    esac
done
if [[ $NTYPE = "pg_dumpall" && -n "$DB" ]]; then
    echo "ERROR: Wrong type of dump. Use '-a' without DB!!!See Help below"
    HELP
    exit 2
fi
DB1=$DB
if [[ -n $SUFFIX && -n $DB  ]];then
DB1="$DB-$SUFFIX"
fi
DUMP_FM="$DUMP_DIR/$host-$timestamp"
if [[ -n $DB   && -n $SCHEMADUMP ]];then
     DUMP_F="$DUMP_FM-$DB1.$TYPEDUMP.$SCHEMADUMP"
elif [[ -n $DB && -z $SCHEMADUMP ]];then
     DUMP_F="$DUMP_FM-$DB1.$TYPEDUMP"
elif [[ -z $DB && -n $SCHEMADUMP ]];then
     DUMP_F="$DUMP_FM.$TYPEDUMP.$SCHEMADUMP"
else 
     DUMP_F="$DUMP_FM.$TYPEDUMP"
fi
DUMP_F_GZ="$DUMP_F.gz"
DUMP_F_LOG="$DUMP_F.log"

echo "start $TYPEDUMP $DB `date`" > $DUMP_F_LOG
STOP_REP
$NTYPE $PS_SCHEMA $DB -f $DUMP_F 2>>$DUMP_F_LOG
START_REP
echo "end $TYPEDUMP $DB `date`" >> $DUMP_F_LOG
grep "failed" $DUMP_F_LOG > /dev/null 2>&1
if [ $? -eq 0 ] ; then
    echo "ERROR: Bad backup $DUMP_F"
    exit 2
fi
echo "start gzip `date`" >> $DUMP_F_LOG
gzip -c $DUMP_F >  $DUMP_F_GZ 2>> $DUMP_F_LOG 
echo "end gzip `date`" >> $DUMP_F_LOG

