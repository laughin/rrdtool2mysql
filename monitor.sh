#!/bin/bash
# Program:
#   该脚本完成从 .rrd 文件中导出数据到 mysql 数据库。以下为导出数据:
#   HOST_IP:        主机 IP 地址
#   DEVICE_NAME:        设备 rrd 文件全名
#   MONITOR_OBJECT:     rrd数据库 DS(datasource) 名称    
#   MONITOR_TIME:       数据时间
#   MONITOR_STEP:       轮询值
#   MONITOR_VALUE:      rrd DS值
#   TRAFFIC_PORT:       交换机端口   
# History:
# 2011/06/17 Laughin First release
 
 
DBHOST="172.16.0.88"
PORT="3306"
USERNAME="root"
PASSWORD="vega"
 
DBNAME="cacti"
TABLENAME="monitor"
 
SQLFILE="./sqlscript.sql"
 
cd /var/www/html/cacti/rra/
 
RRALIST=$(ls -l | grep '.rrd' | awk '{print $NF}')
#echo ${RRALIST}
 
ARRLENGTH=$(ls -l | grep '.rrd' | awk '{print $NF}' | wc -l)
#echo ${ARRLENGTH}
 
 
i=0
while [ "$i" != ${ARRLENGTH} ]
do
    i=$(($i+1))
    ARRTEMP[${i}]=$(ls -l | grep '.rrd' | awk '{print $NF}' | sed -n "${i}p")
#取出主机ip
    HOST[1]=$(echo ${ARRTEMP[${i}]} | cut -d '_' -f1)
    HOST[2]=$(echo ${ARRTEMP[${i}]} | cut -d '_' -f2)
    HOST[3]=$(echo ${ARRTEMP[${i}]} | cut -d '_' -f3)
    HOST[4]=$(echo ${ARRTEMP[${i}]} | cut -d '_' -f4)
    HOST_IP=$(echo ${HOST[1]}"."${HOST[2]}"."${HOST[3]}"."${HOST[4]})
#取出文件名
    DEVICE_NAME="$(echo ${ARRTEMP[${i}]} | cut -d '.' -f1)"
    TRAFFIC_PORT="$(echo ${ARRTEMP[${i}]} | cut -d '.' -f1 | grep 'traffic' | awk 'BEGIN{FS="_";}{print $NF}')"
#监控轮询时间
    MONITOR_STEP=$(expr substr "$(rrdtool info ${ARRTEMP[${i}]} | grep 'step')" 8 $(expr length "$(rrdtool info  ${ARRTEMP[${i}]} | grep step)"))
#最后更新时间
    LAST_UPDATE=$(expr substr "$(rrdtool info ${ARRTEMP[${i}]} | grep last_update)" 15 $(expr length "$(rrdtool info  ${ARRTEMP[${i}]} | grep last_update)"))
#格式化日期
    FORMAT_DATE=$(date -d "1970-01-01 UTC $(expr substr "$(rrdtool info ${ARRTEMP[${i}]} | grep last_update)" 15 $(expr length "$(rrdtool info  ${ARRTEMP[${i}]} | grep last_update)")) seconds" "+%F %T")
#根据没个 .rrd 文件包含的 ds 值数量判断，如果包含多个 ds 值，只取前两个。
    if [ $(rrdtool info ${ARRTEMP[${i}]} | grep value | wc -l) == 9 ];then
        MONITOR_VALUE=""
        MONITOR_OBJECT=""
        MONITOR_OBJECT=$(rrdtool info ${ARRTEMP[${i}]} | grep value | sed -n '1p' | cut -d '[' -f2 | cut -d ']' -f1)
        MONITOR_VALUE=$(rrdtool info ${ARRTEMP[${i}]} | grep value | sed -n '1p' | cut -d '=' -f2)
        if [ $(echo ${MONITOR_VALUE} | grep NaN) ];then
            MONITOR_VALUE=""
        fi
        echo "INSERT INTO \`${TABLENAME}\` (\`hostIp\`,\`deviceName\`,\`monitorObject\`,\`monitorTime\`,\`monitorStep\`,\`monitorValue\`,\`trafficPort\`) VALUES ('${HOST_IP}','${DEVICE_NAME}','${MONITOR_OBJECT}','${FORMAT_DATE}','${MONITOR_STEP}','${MONITOR_VALUE}','${TRAFFIC_PORT}');" >> ${SQLFILE}
    else
        j=0
        while [ "$j" != 2 ]
        do
            j=$(($j+1))
            MONITOR_VALUE=""
            MONITOR_OBJECT=""
            MONITOR_OBJECT=$(rrdtool info ${ARRTEMP[${i}]} | grep value | sed -n "${j}p" | cut -d '[' -f2 | cut -d ']' -f1)
            MONITOR_VALUE=$(rrdtool info ${ARRTEMP[${i}]} | grep value | sed -n "${j}p" | cut -d '=' -f2)
            if [ $(echo {MONITOR_VALUE} | grep NaN) ];then
                MONITOR_VALUE=""
            fi
            echo "INSERT INTO \`${TABLENAME}\` (\`hostIp\`,\`deviceName\`,\`monitorObject\`,\`monitorTime\`,\`monitorStep\`,\`monitorValue\`,\`trafficPort\`) VALUES ('${HOST_IP}','${DEVICE_NAME}','${MONITOR_OBJECT}','${FORMAT_DATE}','${MONITOR_STEP}','${MONITOR_VALUE}','${TRAFFIC_PORT}');" >> ${SQLFILE}
        done
    fi
 
done
 
#执行 mysql 命令导入临时创建的 .sql 文件，把记录插入数据库。
mysql -h${DBHOST} -P${PORT} -u${USERNAME} -p${PASSWORD} ${DBNAME} < ${SQLFILE}
#执行插入完毕后删除临时文件。
rm -rf ${SQLFILE}
 
exit 0
