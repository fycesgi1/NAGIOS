#!/bin/bash
#################################################################################
# Script:       check_px6-300d.sh                                               #
# Author:       Rumen Rachkov (http://www.rumen.in)        						#
# Based on: 	Claudio Kuenzler's check_storcenter								#
# Description:  Plugin for Nagios to check an Lenovo EMC/Iomega            		#
#               Storcenter px6-300d device with SNMP (v3).                      #
# License:      GPLv2                                                           #
# History:      20130830 - firmware 4.0.4.14600	update							#
#				20130802 - raid verification status added						#
#				20130729 - first release                                        #
#																				#
#################################################################################
# Usage:        ./check_px6-300d.sh -H host -U user -t type [-w warning] [-c critical]
#################################################################################
help="check_px6-300d.sh (c) 2013 Rumen Rachkov published under GPL license
\nUsage: ./check_px6-300d.sh -H host -U user -t type [-w warning] [-c critical]
\nRequirements: snmpwalk, tr\n
\nOptions: \t-H hostname\n\t\t-U user (to be defined in snmp settings on Storcenter)\n\t\t-t Type to check, see list below
\t\t-w Warning Threshold (optional)\n\t\t-c Critical Threshold (optional)\n
\nTypes: \t\tdisk -> Checks hard disks for their current status
\t\traid -> Checks the RAID status
\t\tinfo -> Outputs some general information of the device"

# Nagios exit codes and PATH
STATE_OK=0              # define the exit code if status is OK
STATE_WARNING=1         # define the exit code if status is Warning
STATE_CRITICAL=2        # define the exit code if status is Critical
STATE_UNKNOWN=3         # define the exit code if status is Unknown
PATH=$PATH:/usr/local/bin:/usr/bin:/bin # Set path

# If the following programs aren't found, we don't launch the plugin
for cmd in snmpwalk tr [
do
 if ! `which ${cmd} 1>/dev/null`
 then
 echo "UNKNOWN: ${cmd} does not exist, please check if command exists and PATH is correct"
 exit ${STATE_UNKNOWN}
 fi
done
#################################################################################
# Help
if [ "${1}" = "--help" -o "${#}" = "0" ];
       then
       echo -e "${help}";
       exit 1;
fi
#################################################################################
# Get user-given variables
while getopts "H:U:A:t:w:c:d:" Input;
do
       case ${Input} in
       H)      host=${OPTARG};;
       U)      user=${OPTARG};;
	   A)	   pass=${OPTARG};;
       t)      type=${OPTARG};;
       w)      warning=${OPTARG};;
       c)      critical=${OPTARG};;
	   d)	   drive=${OPTARG};;
       *)      echo "Wrong option given. Please use options -H for host, -U for SNMP-User, -A for Password, -t for type, -w for warning and -c for critical"
               exit 1
               ;;
       esac
done
#################################################################################
# Let's check that thing
case ${type} in

# Disk Check
disk)   disknames=($(snmpwalk -v 3 -u ${user} -l authNoPriv -A ${pass} -O vqe ${host} .1.3.6.1.4.1.11369.10.4.3.1.2 | tr ' ' '-'))
        countdisks=${#disknames[*]}
        diskstatus=($(snmpwalk -v 3 -u ${user} -l authNoPriv -A ${pass} -O vqe ${host} .1.3.6.1.4.1.11369.10.4.3.1.4 | tr '"' ' '))
        diskstatusok=0
        diskstatusforeign=0
        diskstatusfaulted=0
        diskstatusmissing=0
        disknumber=0

        for status in ${diskstatus[@]}
        do
                if [ $status = "NORMAL" ]; then diskstatusok=$((diskstatusok + 1)); fi
                if [ $status = "FOREIGN" ]; then diskstatusforeign=$((diskstatusforeign + 1)); diskproblem[${disknumber}]=${disknames[${disknumber}]}; fi
                if [ $status = "FAULTED" ]; then diskstatusfaulted=$((diskstatusfaulted + 1)); diskproblem[${disknumber}]=${disknames[${disknumber}]}; fi
                if [ $status = "MISSING" ]; then diskstatusmissing=$((diskstatusmissing + 1)); fi
        let disknumber++
        done

        if [ $diskstatusforeign -gt 0 ] || [ $diskstatusfaulted -gt 0 ]
        then echo "DISK CRITICAL - ${#diskproblem[@]} disk(s) failed (${diskproblem[@]})"; exit ${STATE_CRITICAL};
        elif [ $diskstatusmissing -gt 0 ]
        then echo "DISK OK - ${countdisks} disks found, ${diskstatusmissing} disks missing/empty"; exit ${STATE_OK}
        elif [ $countdisks -eq $diskstatusok ]
		then echo "DISK OK - ${countdisks} disks found, no problems"; exit ${STATE_OK}
		else echo "UNKNOWN STATUS - ${countdisks} disks found, ${diskstatusok} disks OK"; exit ${STATE_CRITICAL}
        fi
;;

# Disk IO Status
io)		for i in 2 3 4 5 6 7 8 9 10 11 12 13
		do
			disk_io[${i}]=$(snmpwalk -v 3 -u ${user} -l authNoPriv -A ${pass} -O vqe ${host} .1.3.6.1.4.1.11369.10.2.1.1.${i}.${drive})
		done 
		echo "${disk_io[2]}, ${disk_io[3]}, ${disk_io[4]}, ${disk_io[5]}, ${disk_io[6]}, ${disk_io[7]}, ${disk_io[8]}, ${disk_io[9]}, ${disk_io[10]}, ${disk_io[11]}, ${disk_io[12]}, ${disk_io[13]}" ; exit ${STATE_OK}
;;
		
# Raid Check
raid)   raidstatus=$(snmpwalk -v 3 -u ${user} -l authNoPriv -A ${pass} -O vqe ${host} .1.3.6.1.4.1.11369.10.4.1.0 | tr '"' ' ')
        raidtype=$(snmpwalk -v 3 -u ${user} -l authNoPriv -A ${pass} -O vqe ${host} .1.3.6.1.4.1.11369.10.4.2.0)

        if [ $raidstatus = "REBUILDING" ] || [ $raidstatus = "DEGRADED" ] || [ $raidstatus = "REBUILDFS" ]
        then echo "RAID WARNING - RAID $raidstatus"; exit ${STATE_WARNING}
        elif [ $raidstatus = "FAULTED" ]
        then echo "RAID CRITICAL - RAID $raidstatus"; exit ${STATE_CRITICAL}
	elif [ $raidstatus = "NORMAL" ]
	then echo "RAID OK (Raid $raidtype)"; exit ${STATE_OK};
        elif [ -z "$raidstatus" ]
	then echo "RAID VERIFYING (Raid $raidtype)"; exit ${STATE_OK};
	else echo "UNKNOWN STATUS (Raid $raidtype)"; exit ${STATE_WARNING}
        fi
;;

#Temperature
temp)	cputemp=$(snmpwalk -v 3 -u ${user} -l authNoPriv -A ${pass} -O vqe ${host} .1.3.6.1.4.1.11369.10.6.2.1.3.1)
		hddtemp=$(snmpwalk -v 3 -u ${user} -l authNoPriv -A ${pass} -O vqe ${host} .1.3.6.1.4.1.11369.10.6.2.1.3.2)
		p1temp=$(snmpwalk -v 3 -u ${user} -l authNoPriv -A ${pass} -O vqe ${host} .1.3.6.1.4.1.11369.10.6.2.1.3.5)
		p2temp=$(snmpwalk -v 3 -u ${user} -l authNoPriv -A ${pass} -O vqe ${host} .1.3.6.1.4.1.11369.10.6.2.1.3.6)
		if [ $cputemp -gt 70 ] || [ $hddtemp -gt 52 ] || [ $p1temp -gt 52 ] || [ $p2temp -gt 52 ]
        then echo "TEMP CRITICAL - CPU: ${cputemp} Disk: ${hddtemp} Power 1: ${p1temp} Power 2: ${p2temp}"; exit ${STATE_CRITICAL};
        elif [ $cputemp -gt 65 ] || [ $hddtemp -gt 50 ] || [ $p1temp -gt 50 ] || [ $p2temp -gt 50 ]
		then echo "TEMP WARNING - CPU: ${cputemp} Disk: ${hddtemp} Power 1: ${p1temp} Power 2: ${p2temp}"; exit ${STATE_WARNING}
		else echo "TEMP OK - CPU: ${cputemp} Disk: ${hddtemp} Power 1: ${p1temp} Power 2: ${p2temp}" ; exit ${STATE_OK}
		fi
;;

#Voltage
volt)	v12=$(snmpwalk -v 3 -u ${user} -l authNoPriv -A ${pass} -O vqe ${host} .1.3.6.1.4.1.11369.10.6.3.1.3.1)
		v5=$(snmpwalk -v 3 -u ${user} -l authNoPriv -A ${pass} -O vqe ${host} .1.3.6.1.4.1.11369.10.6.3.1.3.2)
		v3=$(snmpwalk -v 3 -u ${user} -l authNoPriv -A ${pass} -O vqe ${host} .1.3.6.1.4.1.11369.10.6.3.1.3.3)
		#batvol=$(snmpwalk -v 3 -u ${user} -l authNoPriv -A ${pass} -O vqe ${host} .1.3.6.1.4.1.11369.10.6.3.1.3.4)
		#memvol=$(snmpwalk -v 3 -u ${user} -l authNoPriv -A ${pass} -O vqe ${host} .1.3.6.1.4.1.11369.10.6.3.1.3.5)
		if [ $v12 -gt 13000 ] || [ $v5 -gt 6000 ] || [ $v3 -gt 4000 ] || [ $v12 -lt 11000 ] || [ $v5 -lt 4000 ] || [ $v3 -lt 2000 ]
			then echo "VOLTAGE CRITICAL - 12V: ${v12} 5V: ${v5} 3V: ${v3}"; exit ${STATE_CRITICAL};
        elif [ $v12 -gt 12500 ] || [ $v5 -gt 5500 ] || [ $v3 -gt 3500 ] || [ $v12 -lt 11500 ] || [ $v5 -lt 4500 ] || [ $v3 -lt 2500 ] 
			then echo "VOLTAGE WARNING - 12V: ${v12} 5V: ${v5} 3V: ${v3}"; exit ${STATE_WARNING}
		else echo "VOLTAGE OK - 12V: ${v12} 5V: ${v5} 3V: ${v3}" ; exit ${STATE_OK}
		fi
;;

#Fans
fan)	cpufan=$(snmpwalk -v 3 -u ${user} -l authNoPriv -A ${pass} -O vqe ${host} .1.3.6.1.4.1.11369.10.6.1.1.3.3)
		hddfan1=$(snmpwalk -v 3 -u ${user} -l authNoPriv -A ${pass} -O vqe ${host} .1.3.6.1.4.1.11369.10.6.1.1.3.1)
		hddfan2=$(snmpwalk -v 3 -u ${user} -l authNoPriv -A ${pass} -O vqe ${host} .1.3.6.1.4.1.11369.10.6.1.1.3.2)
		if [ $cpufan -gt 2300 ] || [ $hddfan1 -gt 1100 ] || [ $hddfan2 -gt 1100 ] || [ $cpufan -lt 1300 ] || [ $hddfan1 -lt 500 ] || [ $hddfan2 -lt 500 ]
        then echo "FANs CRITICAL - CPU Fan: ${cpufan} Disk Fan 1: ${hddfan1} Disk Fan 2: ${hddfan2}"; exit ${STATE_CRITICAL};
        elif [ $cpufan -gt 2200 ] || [ $hddfan1 -gt 1000 ] || [ $hddfan2 -gt 1000 ] || [ $cpufan -lt 1500 ] || [ $hddfan1 -lt 700 ] || [ $hddfan2 -lt 700 ]
		then echo "FANs WARNING - CPU Fan: ${cpufan} Disk Fan 1: ${hddfan1} Disk Fan 2: ${hddfan2}"; exit ${STATE_WARNING}
		else echo "FANs OK - CPU Fan: ${cpufan} Disk Fan 1: ${hddfan1} Disk Fan 2: ${hddfan2}" ; exit ${STATE_OK}
		fi
		
;;

# General Information
info)   hostname=$(snmpwalk -v 3 -u ${user} -l authNoPriv -A ${pass} -O vqt ${host} .1.3.6.1.4.1.11369.10.1.2.0)
        description=$(snmpwalk -v 3 -u ${user} -l authNoPriv -A ${pass} -O vqt ${host} .1.3.6.1.4.1.11369.10.1.1.0)

        echo "${hostname} (${description})"; exit ${STATE_OK}
;;

esac

echo "Unknown error"; exit ${STATE_UNKNOWN}

