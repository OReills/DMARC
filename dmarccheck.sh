#!/bin/bash

# Working path, default is in current directory (pwd)
#wpath="`pwd`"
wpath="`echo $HOME/`"

# Location of dig utility and @<dns server ip to be use>
_dig="/usr/bin/dig @8.8.8.8"

# Targeted domain list file - create a .txt with your list of _dmarc.domain.com, one per line
filelist="$wpath/domains.txt"

# Log file
log_file=dmarcoutput.log
log="$wpath/$log_file"

# Change log file
output_change="dmarcchanges.html"
change_log="$wpath/$output_change"

# Full CSV report file
output_file="dmarcoutput.csv"
report_file="$wpath/$output_file"

# Last report file
output_file_last="dmarcoutput_last.csv"
report_file_last="$wpath/$output_file_last"

# Email notification, 1 to enable, 0 to disable
email_notification="1"

# Location to mutt
_mail="/usr/bin/mutt"

# Location to rfcdiff
_rfcdiff="`echo $HOME`/rfcdiff/rfcdiff"

# List of emails
email_list="your.email@example.com"

# Enable Archive, 1 to enable, 0 to disable
archive="1"

# Archive location
arc_dir="archived"
arc_file="output-`date +"%Y-%m-%d"`.csv"
arc_log="$wpath/$arc_dir/$arc_file"

# Changes archive location
arcc_dir="archived-changes"
arcc_file="changes-`date +"%Y-%m-%d"`.html"
arcc_log="$wpath/$arcc_dir/$arcc_file"

_help(){
	echo "This script will check and compare the DMARC domains listed in the $filelist file."
	echo "Please create the $filelist and put one domain per line"
	echo " "
	echo "Output from this script : "
	echo "Log - $log "
	echo "Full CSV report - $report_file "
	echo "Last report - $report_file_last "
	echo "Change log - $report_change (If the script detect ANY changes from Last report) "
	echo " "
	echo "Usage :"
	echo "$0 -q : Quite mode, silent on-screen output."
	echo " "
	exit 0
}

if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
        _help
fi

if [ ! -s $filelist ]; then
	echo "`date` - $filelist missing, please create the file (one domain per line)."
	exit 0
fi

if [ -r "$report_file" ]; then
        mv $report_file $report_file_last
fi

if [ "$1" != "-q" ]; then
	echo "`date` - Please use $0 -h or $0 --help to see more options."
fi

if [ "$1" != "-q" ]; then
	echo "`date` - Converting $filelist contents to lowercase..."
fi

# Convert domain name to lowercase
dd if=$filelist of=$filelist.tmp conv=lcase status=none
mv $filelist.tmp $filelist
if [ "$1" != "-q" ]; then
	echo "`date` - Converting done."
fi

_getdmarc(){
	$_dig +short txt "$1" | tr ' ' '\n' |
	while read entry; do
		case "$entry" in
			v:*)
				echo "v:${entry#*:}"
				;;
			include:*)
				echo "$entry(`_getdmarc ${entry#*:}`)"
				;;
		esac
	done
}

echo "`date` - Script started." > $log
echo "Domain Name,DMARC Record" > $report_file

for domain in `cat $filelist`
	do
		ips=(`_getdmarc $domain`)
		echo "$domain,`($_dig +short txt $domain | grep -i dmarc | tr -d '"')`,${ips[*]}" >> $report_file
	done

echo "`date` - Script ended. Full CSV report in $output_file" >> $log

cd $wpath

if [ -r "$report_file_last" ]; then
	_diff=(`diff $report_file $report_file_last`)
	if [ "$_diff" != "" ]; then
		$_rfcdiff --hwdiff $output_file_last $output_file $change_log 2>&1
		echo "New record will be highlighted in <strong><font color='green'>green</font></strong> and subtraction from the record will be highlighted with <strike><font color='red'>red strikethrough.</font></strike><p>" > $log
		egrep -i "strike>|strong>" $change_log >> $log 2>&1
		if [ "$email_notification" == "1" ]; then
			$_mail -e "set content_type=text/html" -s "DMARC Check : Alert! Policy has been changed from last check." -a $change_log -a $report_file -a $report_file_last -- $email_list < $log
		fi
	else
		echo "`date` - No record change from last report" >> $log
		if [ "$email_notification" == "1" ]; then
			$_mail -s "DMARC Check : No policy change." -a $report_file -- $email_list < $log
		fi
	fi
else
	cp $report_file $report_file_last
fi

if [ "$archive" == "1" ]; then
	[ -d "$arc_dir" ] && cp $report_file $arc_log || (mkdir $wpath/$arc_dir && cp $report_file $arc_log)
	if [ -f "$change_log" ] ; then
		[ -d "$arcc_dir" ] && mv $change_log $arcc_log || (mkdir $wpath/$arcc_dir && mv $change_log $arcc_log)
	fi
fi

if [ "$1" != "-q" ]; then
	cat $log
fi
