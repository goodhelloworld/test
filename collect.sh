#!/usr/bin/sh

#input parameter
#${vendor} ${eamName} ${taskId} ${emsName} ${fileType} ${taskType} ${SPOOL_MIDDLECOLLECT} ${SPOOL_COLLECT} ${SPOOL_MIDDLEPARSE} ${SPOOL_PARSE} ${SPOOL_ETC} ${SPOOL_COLLECTBACKUP} ${SPOOL_PARSEBACKUP}

#当拿取的参数的个数不等于14的时候执行then
if [ $# -ne 14 ]; then
#显示字符串
	echo "[$$] The input parameters for launch is not equal 14, so exit."
	#返回数字1
	exit 1;
fi
#定义执行脚本的名字
eamName=$1 #eam包名

taskId=$2 #任务的id
emsName=$3	#ems名字
fileType=$4	#文件类型
taskType=$5	#任务类型
SPOOL_MIDDLECOLLECT=$6
SPOOL_COLLECT=$7
SPOOL_ETC=$8
protocolName=$9
emsIp=${10}
emsPort=${11}
emsUser=${12}
emsPasswd=${13}
emsPath=${14}

#日志
logFile=$IM_LOG/eam.collect.${eamName}.${fileType}.${taskId}.log
#执行级别
level=1
collectRetryTime=2
log4jFile=${IM_COMMON_CONF}/log4j.properties
eamDir=${IM_EAM}/${eamName}

#define file list
LASTFILELIST=${SPOOL_ETC}/${fileType}"."${eamName}"lastfilelist"
NOWFILELIST=${SPOOL_ETC}/${fileType}"."${eamName}"nowfilelist"
COLLECTFILELIST=${SPOOL_ETC}/${fileType}"."${eamName}"collectfilelist"
CHECKFILELIST=${SPOOL_ETC}/${fileType}"."${eamName}"checklist"
FAILEDFILELIST=${SPOOL_ETC}/${fileType}"."${eamName}"failedfilelist"
REDUNDANTFILELIST=${SPOOL_ETC}/${fileType}"."${eamName}"redundantfilelist"
TEMPFILELIST=${SPOOL_ETC}/${fileType}"."${eamName}"tempfilelist"
FINALFILELIST=${SPOOL_ETC}/${fileType}"."${eamName}"finalfilelist"

oper_Ip=$(/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"|head -1)

shell_common=$IM_COMMON_CONF/ShellCommonFunction.sh
#只要$shell_common不存在，-e表示存在，为真
if [ ! -e $shell_common ];then
	echo "Lack of file : $shell_common !"
	echo "[OperationLog][`whoami`][`date +'%Y-%m-%d %H:%M:%S'`][$oper_Ip][${eamName}][collect][failure]" >>$logFile
	exit 1
fi
# /dev/null 代表空设备文件>重定向，首先表示标准输出重定向到空设备文件
#  2>&1表示2的输出重定向等同于1
. $shell_common 1>/dev/null 2>&1
#$?表示代表上一个命令是否执行成功，成功则为0，此处表示如果不等于0则执行下一行
if [ $? -ne 0 ];then
	echo "Execute file : $shell_common errror!"
	echo "[OperationLog][`whoami`][`date +'%Y-%m-%d %H:%M:%S'`][$oper_Ip][${eamName}][collect][failure]" >>$logFile
	exit 1
fi


checkifdown()
{ 
	#兼容路径和文件名带空格的场景
	fileName=$*
	#如果参数的个数小于1个
	if [ $# -lt 1 ]
	then
		log error $logFile 2001 "[$$] There is not enough parameters for checkifdown, so exit check!"
		return 1;
	fi
	#统计行数为1
	if [ `ls "${SPOOL_MIDDLECOLLECT}/${fileName}" | wc -l` -eq 1 ]; then
		#一行一行的读取指定的第五个字段 以空格作为分隔符 判断这个文件下的这个字段是否等与0
		if [ `ls -l "${SPOOL_MIDDLECOLLECT}/${fileName}"|awk '{print $5}'` -eq 0 ]; then	
			echo "${SPOOL_MIDDLECOLLECT}|${fileName}">>${FAILEDFILELIST}
			log error $logFile 0150 "[$$] ${fileName} is not ok, its size is 0."  
			return 1;
		else
			log info $logFile 0150 "[$$] ${fileName} is ok."
			return 0;
		fi
	else
		echo "${SPOOL_MIDDLECOLLECT}|${fileName}">>${FAILEDFILELIST}
	  	log error $logFile 0151 "[$$] ${fileName} is not ok, it's not existed."
		return 1;
	fi
}

removefromfilelist()
{

	if [ ! -e $FAILEDFILELIST ];then
	  	return 0 
	fi
	#cp Copy命令
	cp ${NOWFILELIST} ${TEMPFILELIST}
	#读写cat命令 会把文件内容打印到屏幕
	cat ${FAILEDFILELIST}|awk -F\| '{print $2}'|while read fileName
	do
		repitem="###"${fileName}
		#插入？
		sed -i "s/${fileName}/${repitem}/" ${TEMPFILELIST}  
	  
	done 
	log info $logFile 0331 "[$$] Finish to remove the failed file"
	#读写cat命令，grep中-v反转查找'^###之外的'所有行
	cat ${TEMPLIST}|grep -v '^###'> ${NOWFILELIST}	 
}

fn_del_file()
{
	local file_path=$1
	
	if [[ -n "${file_path}" ]]; then
	#
		if [[ -f "${file_path}" ]]; then
		#忽略不存在的文件强制删除，不提示
			rm -f "${file_path}"
			return 0
		else
			return 0
		fi
	else
		return 1
	fi
}
	

log info $logFile 0000 "[$$] Collect Begin......"
log info $logFile 0010 "[$$] Version: V1.0 "
log info $logFile 0020 "[$$] emsIp: "$emsIp
log info $logFile 0020 "[$$] emsPort: "$emsPort
log info $logFile 0020 "[$$] emsUser: "$emsUser
log info $logFile 0020 "[$$] emsPath: "$emsPath
log info $logFile 0020 "[$$] taskId: "$taskId
log info $logFile 0020 "[$$] emsName: "$emsName
log info $logFile 0020 "[$$] fileType: "$fileType
log info $logFile 0020 "[$$] taskType: "$taskType


starttm=`date +%s%N`

COLLECT_BATCH_FILE_NUMBER=1000
#Set the programe need Variables
JAVA=$JAVA_HOME/bin/java; export JAVA

log info $logFile 0100 "[$$] Check the internet connection between the local and $emsIp by protocol ${protocolName}"


#测试连通性的日志文件
conectLog=${oper_Ip}.eam.collect.connect

#test connection and get file list
#判断协议
if [ "$protocolName" = "FTP" ] 
then
	#
	isConnect=`${JAVA_HOME}/bin/java -classpath ${IM_LIB}/*:${IM_EAM}/${eamName}/collect/collect-common.jar:${CLASSPATH} -Xms512m -Xmx1024m -XX:MaxPermSize=128m -XX:ErrorFile=${IM_LOG}/jvm_crash_collect4TestConnection.log com.inspur.pmv5.eam.FtpConnection "${emsIp}" "${emsPort}" "${emsUser}" "${emsPasswd}" "${IM_LOG}" "${conectLog}" "${log4jFile}" "${taskId}"`
	
	if [ "$isConnect" = "N" ]
	then
	#log info 显示一些信息
		log info $logFile 0100 "[$$] Check the internet connection between the local and $emsIp by protocol ${protocolName}, result is failed."
		exit 1;
	else
		log info $logFile 0100 "[$$] Check the internet connection between the local and $emsIp by protocol ${protocolName}, result is successfully."
	fi
	

	log info $logFile 0100 "[$$] Get file list start."
	#清空NOWFILELIST列表的内容
	cat /dev/null>$NOWFILELIST
    #定义一个getFileListLog
	getFileListLog=${oper_Ip}.eam.collect.getFileList
	#通过java对文件进行读取和写出
	$JAVA -classpath ${IM_LIB}/*:$eamDir/collect/collect-common.jar:${CLASSPATH} -XX:ErrorFile=$IM_LOG/jvm/jvm_crash_getfilelist.log com.inspur.pmv5.eam.GetFtpFileList "${emsIp}" "${emsPort}" "${emsUser}" "${emsPasswd}" "${emsPath}" "${NOWFILELIST}" "${level}" "${taskId}" "${fileType}" "${IM_LOG}" "${getFileListLog}" "${log4jFile}"
	
	cp ${NOWFILELIST} ${SPOOL_ETC}/${fileType}"."${eamName}"filelist_Aftergetfilelist"
  
	fileListNumber=`cat ${NOWFILELIST} | wc -l`
	
	log info $logFile 0100 "[$$] Get file list finish. file list number is ${fileListNumber}"

else
  
	isConnect=`${JAVA_HOME}/bin/java -classpath ${IM_LIB}/*:${IM_EAM}/${eamName}/collect/collect-common.jar:${CLASSPATH} -Xms512m -Xmx1024m -XX:MaxPermSize=128m -XX:ErrorFile=${IM_LOG}/jvm_crash_collect4TestConnection.log com.inspur.pmv5.eam.SftpConnection "${emsIp}" "${emsPort}" "${emsUser}" "${emsPasswd}" "${IM_LOG}" "${conectLog}" "${log4jFile}" "${taskId}"`
	
	if [ "$isConnect" = "N" ]
	then
		log info $logFile 0100 "[$$] Check the internet connection between the local and $emsIp by protocol ${protocolName}, result is failed."
		exit 1;
	else
		log info $logFile 0100 "[$$] Check the internet connection between the local and $emsIp by protocol ${protocolName}, result is successfully."
	fi
	
	

	log info $logFile 0100 "[$$] Get file list start."
	cat /dev/null>$NOWFILELIST
    
	getFileListLog=${oper_Ip}.eam.collect.getFileList
	$JAVA -classpath ${IM_LIB}/*:$eamDir/collect/collect-common.jar:${CLASSPATH} -XX:ErrorFile=$IM_LOG/jvm/jvm_crash_getfilelist.log com/inspur/pmv5/eam/GetSftpFileList "${emsIp}" "${emsPort}" "${emsUser}" "${emsPasswd}" "${emsPath}" "${NOWFILELIST}" "${level}" "${taskId}" "${fileType}" "${IM_LOG}" "${getFileListLog}" "${log4jFile}"
	
	cp ${NOWFILELIST} ${SPOOL_ETC}/${fileType}"."${eamName}"filelist_Aftergetfilelist"
  #以行为单位，定义行数
	fileListNumber=`cat ${NOWFILELIST} | wc -l`
	
	log info $logFile 0100 "[$$] Get file list finish. file list number is ${fileListNumber}"

fi


if [ ! -e $NOWFILELIST ]
then
	echo "No data in the given emsPath: ${emsPath}, so exit!"
	exit 0;
fi

if [ ! -e $LASTFILELIST ];then
	log info $logFile 0102 "[$$] No list of lastfilelist"
	cat /dev/null>$LASTFILELIST
fi


cat /dev/null>${COLLECTFILELIST}

cat ${LASTFILELIST}|grep -v '^ '>${LASTFILELIST}".bak"
cat ${LASTFILELIST}".bak"|sort|uniq>${LASTFILELIST}
fn_del_file ${LASTFILELIST}".bak"

cat ${NOWFILELIST}>${NOWFILELIST}".bak"
cat ${NOWFILELIST}".bak"|sort|uniq>${NOWFILELIST}
fn_del_file ${NOWFILELIST}".bak"

#与lastfilelist对比，去除已采集文件
#REDUNDANTFILELIST冗余的列表，TEMPFILELIST临时
diff ${LASTFILELIST} ${NOWFILELIST}|grep "^< "|awk '{print substr($0,3)}'|sort > ${REDUNDANTFILELIST}
diff ${LASTFILELIST} ${REDUNDANTFILELIST}|grep "^< "|awk '{print substr($0,3)}'|sort > ${TEMPFILELIST}
cp ${TEMPFILELIST} ${LASTFILELIST}
#对比后取到的增量放入collectfilelist列表中
diff ${LASTFILELIST} ${NOWFILELIST}|grep "^> "|awk '{print substr($0,3)}'|sort > ${COLLECTFILELIST}

cp ${COLLECTFILELIST} ${SPOOL_ETC}/${fileType}"."${eamName}"filelist_Afterlastfilelist"
fileListNumber=`cat ${COLLECTFILELIST} | wc -l`
log info $logFile 0104 "[$$] After filter the collection file list by last collection, the collectfilelist number is ${fileListNumber}"
fn_del_file ${REDUNDANTFILELIST}

if [ ${fileListNumber} -eq 0 ]
then
	log info $logFile 0104 "[$$] No file to collect, so exit."
	exit 0;
fi
log info $logFile 0104 "[$$]===Download file start==="

i=0
loop=0
totalNumber=`cat $COLLECTFILELIST|wc -l`
currentNumber=${COLLECT_BATCH_FILE_NUMBER}
#判断收集的数据的条数
while [ $i -lt ${totalNumber} ]
do	
	num=0
	loop=`expr $loop \+ 1`
	case "$loop" in 
		"1")log info $logFile 0301 "[$$] The ${loop}st time collect file ...";;
		"2")log info $logFile 0301 "[$$] The ${loop}nd time collect file ...";;
		"3")log info $logFile 0301 "[$$] The ${loop}rd time collect file ...";;
		*)log info $logFile 0301 "[$$] The ${loop}th time collect file ...";;
	esac
 	
	if [ "$totalNumber" -lt "$COLLECT_BATCH_FILE_NUMBER" ]
	then
		log info $logFile 0030 "[$$] Collect Status: ${totalNumber}/${totalNumber} ..." 
		sta=`echo "${totalNumber}/${totalNumber}"`
	else
		log info $logFile 0030 "[$$] Collect Status: ${currentNumber}/${totalNumber} ..."
		sta=`echo "${currentNumber}/${totalNumber}"`
		currentNumber=`expr $currentNumber \+ $COLLECT_BATCH_FILE_NUMBER` 
	fi
  
	cat /dev/null>${TEMPFILELIST}
	cat /dev/null>${NOWFILELIST}
	
	log info $logFile 0104 "[$$][${sta}]Download the file start..."
	
	#将当前批次的文件存入NOWFILELIST
	tempCount=0
	num=0
	cat $COLLECTFILELIST|grep -v "^ "|while read line
	do	
		tempCount=`expr $tempCount \+ 1`
		if [ "$tempCount" -gt "$i" -a "$num" -lt "$COLLECT_BATCH_FILE_NUMBER" ]; then
			num=`expr $num \+ 1`
			echo ${line}>>${NOWFILELIST}
		fi
	done
	
	num=`cat ${NOWFILELIST}|wc -l`
	i=`expr $i \+ $num`
	
	cp ${NOWFILELIST} ${SPOOL_ETC}/${fileType}"."${eamName}"finalfilelist"
	
	
	#生成checkfilelist
	cat ${NOWFILELIST}|awk -F\| '{print "checkifdown "$1}' > ${CHECKFILELIST}

	
	getFileLog=${oper_Ip}.eam.collect.getFile
	
	if [ "$protocolName" == "FTP"  ] 
	then
  
		$JAVA -classpath ${IM_LIB}/*:$eamDir/collect/collect-common.jar:${CLASSPATH} com.inspur.pmv5.eam.GetFtpFile "${emsIp}" "${emsPort}" "${emsUser}" "${emsPasswd}" "${NOWFILELIST}" "${SPOOL_MIDDLECOLLECT}" "${taskId}" "${collectRetryTime}" "${IM_LOG}" "${getFileLog}" "${log4jFile}" 
		
	else
		
		$JAVA -classpath ${IM_LIB}/*:$eamDir/collect/collect-common.jar:${CLASSPATH} com.inspur.pmv5.eam.GetSftpFile "${emsIp}" "${emsPort}" "${emsUser}" "${emsPasswd}" "${NOWFILELIST}" "${SPOOL_MIDDLECOLLECT}" "${taskId}" "${collectRetryTime}" "${IM_LOG}" "${getFileLog}" "${log4jFile}" 
	
	fi
	
	log info $logFile 0104 "[$$][${sta}]Download the file finish"
	
	#check file exist
	log info $logFile 0320 "[$$] [${sta}]Check whether exist failed file start..."
	num=0
	cat ${CHECKFILELIST}|grep -v "^ "|while read listitem
	do
		if [ "$num" -lt "$COLLECT_BATCH_FILE_NUMBER" ];then
			num=`expr $num \+ 1`
			$listitem		
		else
			break
		fi
		
	done
	log info $logFile 0320 "[$$] [${sta}]Check whether exist failed file finish."
	
	#remove failed file from lastfilelist
	log info $logFile 0330 "[$$] [${sta}]Remove the failed collected file from file list start..."
	removefromfilelist 	
	log info $logFile 0330 "[$$] [${sta}]Remove the failed collected file from file list finish."
	
	#####Decompression start
	cd ${SPOOL_MIDDLECOLLECT}
	
	ls|grep '.zip$'|while read zipfile
	do
		log info $logFile 0330 "[$$] [${sta}] unzip file: ${zipfile}"
		unzip "${zipfile}"
		rm "${zipfile}"
	done
	
	ls|grep '.tar.gz$'|while read targzfile
	do
		log info $logFile 0330 "[$$] [${sta}] tar -zxvf file: ${targzfile}"
		tar -zxvf "${targzfile}"
		rm "${targzfile}"
	done
	
	ls|grep '.gz$'|while read gzFile
	do
		log info $logFile 0330 "[$$] [${sta}] gunzip file: ${gzFile}"
		gunzip "${gzFile}"
	done
	
	##Decompression end
	
	log info $logFile 0340 "[$$] [${sta}]Move collected file from middlecollect to collect start..."
	
	#从middlecollect目录移到collect目录，对于含有DaylightSaveInfo关键字乱码的文件，先将改行删除
	ls|while read fileName 
	do
		sed -i /.*DaylightSaveInfo.*/d "${fileName}"
		mv "${fileName}" "${SPOOL_COLLECT}"
	done
	log info $logFile 0340 "[$$] [${sta}]Move collected file from middlecollect to collect finish."
	
	cat ${NOWFILELIST}|grep -v "^ " >> ${LASTFILELIST}
	cat ${LASTFILELIST}|sort|uniq> ${NOWFILELIST}
	cp "${NOWFILELIST}" "${LASTFILELIST}"
	log info $logFile 0350 "[$$] [${sta}]Add this time collected files to lastfilelist."
	
	
	case "$loop" in 
		"1")log info $logFile 0360 "[$$] The ${loop}st time collect file finished ...";;
		"2")log info $logFile 0360 "[$$] The ${loop}nd time collect file finished ...";;
		"3")log info $logFile 0360 "[$$] The ${loop}rd time collect file finished ...";;
		*)log info $logFile 0360 "[$$] The ${loop}th time collect file finished ...";;
	esac
done

log info $logFile 0104 "[$$]===Download file end==="

if [ -e $FAILEDFILELIST ];then		
	mv "${FAILEDFILELIST}" "${FAILEDFILELIST}.bak"
fi
if [ -e $LASTFILELIST ];then		
	cp "${LASTFILELIST}" "${LASTFILELIST}.bak"
fi

fn_del_file $NOWFILELIST
fn_del_file $CHECKFILELIST 2>/dev/null
fn_del_file $COLLECTFILELIST 2>/dev/null
fn_del_file $TEMPFILELIST 2>/dev/null
endtm=`date +%s%N`
endtm=`expr $endtm \- $starttm`
endtm=`expr $endtm / 1000000`

log info $logFile 0999 "[$$] Collect End. Collected files $totalNumber. Cost $endtm milliseconds"
echo "[OperationLog][`whoami`][`date +'%Y-%m-%d %H:%M:%S'`][$oper_Ip][M2000 R11][collect][success]" >>$logFile

