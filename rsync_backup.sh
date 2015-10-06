#!/bin/bash

echo "=================== Hello! This is an rsync backup script =======================
Please enter the Username, the Password and the Hostname from the Rsync Instruction.
A server hostname usually matchs the one in a Rsync Instruction, but not in all cases.
So, please be attentive entering the Hostname.
=======================================================================================
"
# Enter Username, Password and Hostname

read -p "Username: " RSYNC_USER
read -p "Password: " RSYNC_PASSWD
read -e -p "Hostname:" -i "$HOSTNAME" RSYNC_HOST

#Determining time for a backup

echo
echo "=============== Preliminary information ==============="
echo
echo "- Current time: `date`"
echo "- Current time zone: `date +'%:z %Z'`"
echo

#################################################################
### Detect a distro
#################################################################

# DISTR variables description ("cpanel", "plesk", "ispm", "unknown")

echo -n "- "
lsb_release -ds 2>/dev/null || cat /etc/*release 2>/dev/null | head -n1 || uname -om
 if [ -f /usr/local/cpanel/cpanel ]; then
    echo "- cPanel:" `/usr/local/cpanel/cpanel -V`
    DISTR="cpanel"
    MYSQL_CRED="mysql"
 elif [ -f /usr/local/psa/version ]; then
    echo "- Plesk v."`cat /usr/local/psa/version`
    DISTR="plesk"
    MYSQL_CRED="mysql -uadmin -p`cat /etc/psa/.psa.shadow`"
 elif [ -f /usr/local/ispmgr/bin/ispmgr ]; then
    echo "- " `/usr/local/ispmgr/bin/ispmgr -v`
    DISTR="ispm"
    MYSQL_CRED="mysql -u"`awk '$1=="User" {print$2}' /usr/local/ispmgr/etc/ispmgr.conf`" mysql -p"`awk '$1=="Password" {print$2}' /usr/local/ispmgr/etc/ispmgr.conf`""
 else
    DISTR="unknown"
    MYSQL_CRED="mysql"
 fi

#OS detecting ("rpm", "deb")

 if [ -s /etc/redhat-release ]; then
    OS="rpm"
    CRONTAB="/var/spool/cron/root"
 elif [ -s /etc/debian_version ]; then
    OS="deb"
    CRONTAB="/var/spool/cron/crontabs/root"
 fi

echo
echo "======================================================="
#################################################################
### Enabling MySQL dumps
#################################################################

for i in $(seq 1 3)

  do
     echo
     echo -n "* Testing connection to Mysql: "
     $MYSQL_CRED -e exit 2>&-
     [ $? -eq 0 ] && echo "SUCCESS" && echo && break || echo "FAILED !!!!!" && echo && [ $i -eq 1 ] &&

     while [ -z $prompt ]; do
        echo
        read -e -p "==> Do you want to enable MySQL dumps (y/n)?" -i "y" choice
        echo
        case "$choice" in
          y|Y|yes|YES ) prompt=true; do_mysql="yes"; break;;
          n|N|no|NO ) prompt=true; do_mysql="no"; break 2;;
          * ) prompt=false; continue;;
        esac
     done

     [ $i -eq 2 ] && echo "
     !!!!! Make sure you entered the correct credentials. Also, try using password with the single quotes ''
     "
     [ $i -eq 3 ] && echo "
     !!!!! MySQL backups have been skipped !!!!!
     " && do_mysql="no" && break
     read -p "==> Enter a MySQL admin User: " mysql_user
     echo
     read -p "==> Enter a MySQL admin Password: " mysql_passwd

     MYSQL_CRED="mysql -u$mysql_user mysql -p$mysql_passwd"

  done

prompt=;

#################################################################
### Defining the Daily_cron and the Weekly_cron functions
#################################################################

Daily_cron_time()
{
  incr=0
  while [[ $incr != 1 ]]; do
    echo
    read -e -p "==> Set minutes for the cron [0-59]):" -i "0" cron_min
 
    #check minutes
      if [[ "$cron_min" =~ ^([0-5]?[0-9])$ ]]; then
          (( incr++ ))
      else
         echo "!!!!! incorrect minutes: $cron_min (Numbers from the range 0-59 are allowed only) !!!!!"
         continue
      fi
  done

  incr=0
  while [[ $incr != 1 ]]; do
    echo
    read -p "==> Set hours for the cron [0-23]):" cron_hour

    #check hours
      if [[ "$cron_hour" =~ ^([01]?[0-9]|2[0-3])$ ]]; then
         (( incr++ ))
      else
         echo "!!!!! incorrect hours: $cron_hour (Numbers from the range 0-23 are allowed only) !!!!!"
         continue
      fi
  done
  
  CRONTIME="$cron_min $cron_hour * * *"

  if [ $cron_hour -eq 22 -o $cron_hour -eq 23 ]; then
     ((cron_hour-=22))
  else ((cron_hour+=2))
  fi
  
  MYSQL_CRONTIME_DAILY="$cron_min $cron_hour * * *"
  RAND=`echo $((RANDOM%6+0))`
  MYSQL_CRONTIME_WEEKLY="$cron_min $cron_hour * * $RAND"

}

##############################################################
Weekly_cron_time()
{
 incr=0
  while [[ $incr != 1 ]]; do
    echo
    read -e -p "==> Set minutes for the cron [0-59]): " -i "0" cron_min

    #check minutes
      if [[ "$cron_min" =~ ^([0-5]?[0-9])$ ]]; then
          (( incr++ ))
      else
         echo "!!!!! incorrect minutes: $cron_min (Numbers from the range 0-59 are allowed only) !!!!!"
         continue
      fi
  done
    
  incr=0
  while [[ $incr != 1 ]]; do
    echo
    read -p "==> Set hours for the cron [0-23]: " cron_hour

    #check hours
      if [[ "$cron_hour" =~ ^([01]?[0-9]|2[0-3])$ ]]; then
         (( incr++ ))
      else
         echo "!!!!! incorrect hours: $cron_hour (Numbers from the range 0-23 are allowed only) !!!!!"
         continue
      fi
  done

  incr=0
  while [[ $incr != 1 ]]; do
    echo
    read -p "==> Set a day of the week for the cron (0=Sunday, 1-Monday)[0-6]: " cron_week

    #check the day of the week
      if [[ "$cron_week" =~ ^([0-6])$ ]]; then
          (( incr++ ))
      else
         echo "!!!!! incorrect the day of the week: (Numbers from the range 0-6 are allowed only) !!!!!"
      fi
  done

  CRONTIME="$cron_min $cron_hour * * $cron_week"
 
  if [ $cron_hour -eq 22 -o $cron_hour -eq 23 ]; then
     ((cron_hour-=22))
     ((cron_week+=1))
  
     if [ $cron_week -eq 7 ]; then
        cron_week=0
     fi
  
  else
     ((cron_hour+=2))
  fi
 
  MYSQL_CRONTIME_WEEKLY="$cron_min $cron_hour * * $cron_week"
  MYSQL_CRONTIME_DAILY="$cron_min $cron_hour * * *"

}

#################################################################
### Defining a Mysql_backup() function for a MySQL dump scripts.
#################################################################

# /usr/local/src/make_mysql_dumps_Daily.sh and 
# /usr/local/src/make_mysql_dumps_Weekly.sh are supposed to be created

Mysql_backup(){

cat <<EOF >/usr/local/src/make_mysql_dumps_$1.sh
#!/bin/bash

dt=\`date +"%d.%m.%Y"\ "%T"\`

# get databases

DB_EXCLUDE='Database|information_schema|eximstats|cphulkd|horde|modsec|mysql|leechprotect|performance_schema|roundcube|whmxfer'
dbs=\`echo 'show databases;' | $2 | grep -vE \$DB_EXCLUDE\`

# make target directory

[ -d /usr/local/src/mysql_dumps_$1 ] || mkdir -p /usr/local/src/mysql_dumps_$1

for db in \$dbs;

do

  echo -n "[\$dt] making a mysqldump of [\$db]: "
  mysqldump --opt --databases \$db | gzip > /usr/local/src/mysql_dumps_$1/\$db.sql.gz

  if [ $? -eq 0 ]; then
     echo "DONE"
  else
     echo "FAILED"
  fi

done

echo -n "[\$dt] sending $1 MYSQL DUMPs to the RSYNC backup server: "

rsync -avz -e ssh /usr/local/src/mysql_dumps_$1/* $RSYNC_USER@rsync1.cloudkeeper.net:$RSYNC_HOST/mysql_dumps_$1/

rm -rf /usr/local/src/mysql_dumps_$1/*

echo "==== FINISHED ====
"
EOF
}

#################################################################
### Organizing an auth to the Rsync server using SSH RSA key
#################################################################

# Generating an SSH RSA key pair

if [ ! -f ~/.ssh/id_rsa.pub ]; then
   echo -n "* Generating an SSH RSA key pair :"
   ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa | 1>&- 2>&-
   if [ $? -eq 0 ]; then
      echo "DONE"
      echo
   else
      echo "FAILED !!!!!"
      exit 1
   fi
fi

# copy an SSH RSA public key to the rsync server and mergekeys
#check/install sshpass

SSHpassInstall()
{
for i in $(seq 1 2)
  do
     if which curl >/dev/null; then
        cd /usr/src
        `which curl` -O -L http://sourceforge.net/projects/sshpass/files/sshpass/1.05/sshpass-1.05.tar.gz 2>/dev/null
        `which tar` -xzf sshpass-1.05.tar.gz
        cd sshpass-1.05
        ./configure >/dev/null
        make >/dev/null
        make install >/dev/null
        break
     else
         echo -n "* Curl isn't installed. Installing curl: "
         yum install -y curl 1>/dev/null
         [ $? -eq 0 ] && echo "SUCCESS" || echo "FAILED" && exit 1
     fi
  done
}

which sshpass 1>&- 2>&-

if [ $? -eq 0 -o -s /usr/bin/sshpass -o -s /usr/local/bin/sshpass ]; then
   echo "* sshpass utility is already installed"
else
   case "$OS" in
     deb ) apt-get install --force-yes sshpass 1>/dev/null;;
     rpm ) SSHpassInstall > /dev/null 2>&1;;
   esac
   [ $? -ne 0 ] && echo "!!!!! something went wrong with the sshpass utility installation !!!!!" && exit 1 
fi

copy_key(){
`which sshpass` -p $RSYNC_PASSWD scp -o StrictHostKeyChecking=no -o LogLevel=quiet ~/.ssh/id_rsa.pub $RSYNC_USER@rsync1.cloudkeeper.net:keys/$RSYNC_HOST | 1>&- 2>&-
`which sshpass` -p $RSYNC_PASSWD ssh $RSYNC_USER@rsync1.cloudkeeper.net mergekeys
}

## running the copy_key function
# give 4 tries
echo
echo -n "* Copying and marging keys: "

for i in $(seq 1 4)
  do
    copy_key $RSYNC_USER $RSYNC_HOST $RSYNC_PASSWD
    if [ $? -eq 0 ]; then
       echo "DONE"
       break
    elif [ $i -eq 3 ]; then
       echo "208.122.4.62 rsync1.cloudkeeper.net" >> /etc/hosts
    elif [ $i -eq 4 ]; then
       echo "FAILED !!!!! The key hasn't been copied !!!!!"
       exit 1
    fi
    sleep 2
  done

#################################################################
### Test rsync by syncing /etc folder
#################################################################
echo
echo -n "* Testing rsync syncing the /etc folder: "
  
for i in $(seq 1 2)
  do
     `which rsync` -avz -e "ssh -i ~/.ssh/id_rsa" /etc $RSYNC_USER@rsync1.cloudkeeper.net:$RSYNC_HOST/ > /dev/null 2>&1
       
       if [ $? -eq 0 ];then
          echo "SUCCESS"
          break
       else
          `which rsync`
          [ $? -ne 0 ] &&
           
          case "$OS" in
            deb ) apt-get install --force-yes rsync 1>/dev/null;;
            rpm ) yum install -y rsync 1>/dev/null;;
          esac
     
          [ $? -ne 0 ] && echo "FAILED!!!!! something went wrong with the rsync utility installation !!!!!" && exit 1
       fi
  done

#################################################################
### Choosing a type of a backup (Daily or Weekly)
#################################################################

  while [ -z $prompt ]; do
     echo
     read -e -p "==> Is it a Daily(d) or Weekly(w) backup (d/w)?" -i "d" choice;
     case "$choice" in
       d|D ) prompt=true; Daily_cron_time; Mysql_backup "Daily" "$MYSQL_CRED"; Mysql_backup "Weekly" "$MYSQL_CRED"; break;;
       w|W ) prompt=true; Weekly_cron_time; Mysql_backup "Daily" "$MYSQL_CRED"; Mysql_backup "Weekly" "$MYSQL_CRED"; break;;
       * ) prompt=false; echo "set \"d\" or \"w\""; continue;;
     esac
   done

   prompt=;
   
#################################################################
### Setting up cron lines
#################################################################

echo
echo -n "* Setting up cron lines: "

# for main Rsync

echo "$CRONTIME `which rsync` -avz --delete --exclude=virtfs --exclude=tmp --exclude=/tmp --exclude=/lost+found \
--exclude=/proc --exclude=/sys --exclude=/dev --exclude=tmpDSK -e ssh / $RSYNC_USER@rsync1.cloudkeeper.net:$RSYNC_HOST/ > /var/log/rsync.log 2>&1" >> $CRONTAB

if [ $do_mysql -eq "yes" ]; then

   # for Daily MySQL backups

   echo "$MYSQL_CRONTIME_DAILY `which bash` /usr/local/src/make_mysql_dumps_Daily.sh >> /var/log/rsync_mysql.log 2>&1" >> $CRONTAB

   # for Weekly MySQL backups

   echo "$MYSQL_CRONTIME_WEEKLY `which bash` /usr/local/src/make_mysql_dumps_Weekly.sh >> /var/log/rsync_mysql.log 2>&1" >> $CRONTAB

fi

[ $? -ne 0 ] && echo "!!!!! FAILED !!!!!" && exit 1 || echo "DONE"
echo
echo "=============== Here is the crontab list =============="
crontab -l
echo "======================================================="
echo " 
That's it. Enjoy!"
echo
#################################################################
### Please contact me in case of any errors: denisb@uk2group.com
#################################################################
