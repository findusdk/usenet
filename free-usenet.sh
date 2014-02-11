#!/ffp/bin/sh
#
# This script is written for the use of automation account registration at hitnews.com.
# The site offers 3 days unlimited usenet accounts for free, with SSL and up to 30 connections.
# Dependencies are: coreutils, wget, lynx, nzbget#
#
# Written by findusdk 2014

PATH=/opt/sbin:/opt/bin:/ffp/sbin:/usr/sbin:/sbin:/ffp/bin:/usr/bin:/bin

#define location of the applications and config file needed to use the script
nzbgetcnf="/ffp/etc/nzbget/nzbget.conf" #usenet config file containing login username and password
namelist="/ffp/etc/nzbget/names.csv" #file with a list of random names (comma separated). Got mine from http://www.fakenamegenerator.com/order.php
restart="/ffp/start/nzbget.sh restart" #command for restart of usenet client
useragent="Mozilla/5.0 (Windows NT 6.3; WOW64; rv:26.0) Gecko/20100101 Firefox/26.0" #useragent that lynx and wget should be using
log="/ffp/etc/nzbget/free-usenet.log" #script logfile
lynxscript="/ffp/etc/nzbget/lynxscript.log" #lynx command file

#get list of current domains from temp-mail.ru, and trim it for things we don't need
input=$(wget -q -O - http://api.temp-mail.ru/request/domains/format/php/ | sed '1d;$d')
domains=$(echo "$input" | cut -d "'" -f2 | while read p;do
    echo "$p"
done
)
tempmail=$(tr -dc a-z0-9 < /dev/urandom | head -c 10 | xargs)$(echo "$domains" | shuf -n 1) #email will be 10 random charecters and a random domain from the domainlist
if [ -z $tempmail ];then
	echo "$(date "+%-d-%-m-%Y %T") [ERROR] 	An email address was NOT created." >> $log
	exit
else
	echo "$(date "+%-d-%-m-%Y %T") [OK] 	An email address was created: "$tempmail"" >> $log
fi

#generate tings we need to registrer for an account
randomname=$(shuf -n 1 $namelist | cut -d',' -f1),$(shuf -n 1 $namelist | cut -d',' -f2) #draw random first and last name from the name list
user=$(tr -dc 0-9 < /dev/urandom | head -c 3 | xargs)$(echo "$randomname" | cut -d',' -f1 | tr '[:upper:]' '[:lower:]')\
$(tr -dc 0-9 < /dev/urandom | head -c 2 | xargs)$(echo "$randomname" | cut -d',' -f2 | tr '[:upper:]' '[:lower:]') #make username with three random digits, first name, two random digits and last name
pass=$(tr -dc a-z0-9 < /dev/urandom | head -c 8 | xargs) #Make eight character password
echo "$(date "+%-d-%-m-%Y %T") [OK] 	Credentials created: user \""$user"\" pass \""$pass"\"" >> $log

#create command script for use with account registration on hitnews.com, using the temporary email address, user and password
echo "$(
for TAB in {1..7}
do
	echo "key <tab>"
done

#Input name in form. Could be static, but we use a name list
for FIRSTNAME in $(echo "$randomname" | cut -d',' -f1 | sed 's/\(.\)/\1\n/g')
do
	echo key "$FIRSTNAME"
done
echo "key <tab>"
for LASTNAME in $(echo "$randomname" | cut -d',' -f2 | sed 's/\(.\)/\1\n/g')
do
	echo key "$LASTNAME"
done
echo "key <tab>"

#Input the temporary email as the email account
for MAIL in $(echo "$tempmail" | sed 's/\(.\)/\1\n/g')
do
	echo key "$MAIL"
done

#Using the earlier generated username
echo "key <tab>"

for USERNAME in $(echo "$user" | sed 's/\(.\)/\1\n/g')
do
	echo key "$USERNAME"
done
echo "key <tab>"

#Using the random generated password
for PASSWORD in $(echo "$pass" | sed 's/\(.\)/\1\n/g')
do
	echo key "$PASSWORD"
done
echo "key <tab>"

#And again for the password check
for PASSWORD in $(echo "$pass" | sed 's/\(.\)/\1\n/g')
do
	echo key "$PASSWORD"
done

#Send form, accept user agreement and exit lynx
echo "key <tab>"
echo "key <tab>"
echo "key ^J"
echo "key <tab>"
echo "key <tab>"
echo "key <tab>"
echo "key <tab>"
echo "key ^J"
echo "key <tab>"
echo "key ^J"
echo "key Q"
)" > $lynxscript
if [ -z "$lynxscript" ];then
	echo "$(date "+%-d-%-m-%Y %T") [ERROR] 	A lynx-script has NOT been created" >> $log
else
	echo "$(date "+%-d-%-m-%Y %T") [OK] 	A lynx-script has been created" >> $log
fi

#use the generated script to register for a free account
lynx -useragent="$useragent" -cmd_script="$lynxscript" https://member.hitnews.com/signup.php > /dev/null 2>&1
OUT=$?
if [ $OUT -eq 0 ];then
	echo "$(date "+%-d-%-m-%Y %T") [OK] 	Lynx and the lynx-script was executed successfully" >> $log
else
	echo "$(date "+%-d-%-m-%Y %T") [ERROR]	Lynx and the lynx-script failed." >> $log
	exit
fi
rm $lynxscript

#wait for email to arrive
sleep 10

#get activation link from email sent by hitnews.com
md5mail=$(echo -n "$tempmail" | md5sum | cut -d' ' -f1) #calculates md5sum for tempmail used when checking the temp-mail.ru inbox
activationlink=$(wget -q -O - http://api.temp-mail.ru/request/mail/id/"$md5mail"/format/php/ | grep signup.php)
echo "$(date "+%-d-%-m-%Y %T") [INFO]	Activation-link for this account is: "$activationlink"" >> $log

#visit the link to activate the account
wget -q -O - --user-agent="$useragent" "$activationlink" > /dev/null
OUT=$?
if [ $OUT -eq 0 ];then
	echo "$(date "+%-d-%-m-%Y %T") [OK]		Account was succesfully activated." >> $log
else
	echo "$(date "+%-d-%-m-%Y %T") [ERROR] 	Account could NOT be activated." >> $log
	exit
fi

#There is some waiting time, from using the activation link, to the account is ready for use.
#We check every 10th minute, to see if the account is ready.
until [ "$((echo "authinfo user $user"; echo "authinfo pass $pass"; sleep 1; echo "quit") | telnet free.hitnews.com 119 | sed -n '3{p;q;}' | cut -d' ' -f1)" = "281" ];do
	echo "$(date "+%-d-%-m-%Y %T") [INFO]	Account not active yet. Waiting 10 minutes before retry" >> $log
	sleep 10m
done
echo "$(date "+%-d-%-m-%Y %T") [OK]		Account is now active. Adding new username and password to "$nzbgetcnf"" >> $log

#change account information in downloader config-file with account creation date, and the new user and password
date=$(date "+%T %-d-%-m-%Y")
sed -i "s/^\(Server5\.Username\s*=\s*\).*\$/\1$user/" $nzbgetcnf
sed -i "s/^\(Server5\.Password\s*=\s*\).*\$/\1$pass/" $nzbgetcnf
sed -i "s/^\(Server5\.Name\s*=\s*\).*\$/\1Hitnews ($date)/" $nzbgetcnf

echo "$(date "+%-d-%-m-%Y %T") [OK]		Restarting NZBget." >> $log
$restart >/dev/null 2>&1