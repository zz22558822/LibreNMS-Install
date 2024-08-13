# LibreNMS 安裝腳本
# 注意：腳本將更新並升級目前安裝的軟體包。
# 更新支援到 Ubuntu 24.04
#!/bin/bash
echo "此腳本將安裝 LibreNMS 至您的 Ubuntu 22.04 LTS"
echo "###########################################################"
echo "更新存儲庫快取並安裝所需的存儲庫"
echo "###########################################################"
# Set the system timezone
echo "您是否設定了系統時區?: [yes/no]"
read ANS
if [ "$ANS" = "N" ] || [ "$ANS" = "No" ] || [ "$ASN" = "NO'" ] || [ "$ANS" = "no" ] || [ "$ANS" = "n" ]; then
  echo "接下來將列出時區"
  echo "按下 Q 來退出列表"
  echo "-----------------------------"
  sleep 5
  echo " "
  timedatectl list-timezones
  echo "輸入系統時區:"
  read TZ
  timedatectl set-timezone $TZ
  echo "已設置時區為 $TZ"
  else
   TZ="$(cat /etc/timezone)"
fi
echo " "
echo "更新存儲庫"
apt update
# 安裝所需的套件
echo " "
echo "安裝所需的套件"
apt install -y software-properties-common
add-apt-repository universe
echo "升級系統中已安裝的套件"
echo "###########################################################"
apt upgrade -y
echo "安裝相依性套件"
echo "###########################################################"
sleep 1
echo ""
sleep 1
echo  " 請稍後... "
sleep 2
echo " 目前即將開始安裝... "
echo "###########################################################"
echo "###########################################################"

# 版本 8 已將 json 移至核心程式碼中，它不再是一個單獨的模組。 
# composer, python3-memcashe, 不存在於 22.04 當中
apt install -y acl composer python3-memcache curl fping git graphviz imagemagick mariadb-client \
mariadb-server mtr-tiny nginx-full nmap php8.3-cli php8.3-curl php8.3-fpm \
php8.3-gd php8.3-gmp php8.3-mbstring php8.3-mysql php8.3-snmp php8.3-xml \
php8.3-zip python3-pymysql python3-psutil python3-command-runner python3-dotenv \
python3-redis python3-setuptools python3-systemd python3-pip python3-mysqldb rrdtool \
snmp snmpd whois unzip traceroute \
# 下載 LibreNMS
echo "將 libreNMS 下載到 /opt"
echo "###########################################################"
cd /opt
git clone https://github.com/librenms/librenms.git
# 添加 librenms 使用者
echo "建立 libreNMS 使用者帳戶，設置主目錄，但不建立主目錄"
echo "###########################################################"
# 添加使用者，鏈接主目錄，不創建主目錄，系統使用者
useradd librenms -d /opt/librenms -M -r -s "$(which bash)"
# 添加 librenms 使用者到 www-data 群組
  # echo "將 libreNMS 使用者添加到 www-data 群組"
  # echo "###########################################################"
  # usermod -a -G librenms www-data
# 設置權限和訪問控制
echo "設置權限和文件訪問控制"
echo "###########################################################"
# 在目錄上遞歸設置所有者:群組
chown -R librenms:librenms /opt/librenms
# 修改目錄權限 O=所有，G=所有，其他=無
chmod 771 /opt/librenms
# 修改預設 ACL
setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
# 遞歸修改 ACL
setfacl -R -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
### 安裝 PHP 相依性
echo "使用 librenms 身份運行 PHP 安裝腳本"
echo "###########################################################"
# 運行 PHP 相依性安裝程式
su librenms bash -c '/opt/librenms/scripts/composer_wrapper.php install --no-dev'
# 失敗警告
echo " "
echo "###########################################################"
echo "在使用代理時，腳本可能會失敗。解決方法是手動安裝 composer 套件。請參閱 LibreNMS 的安裝頁面。"
echo " "
sleep 10
# 配置 MySQL (mariadb)
echo "###########################################################"
echo "配置 MariaDB"
echo "###########################################################"
systemctl restart mariadb
# 傳送命令到 mysql 並創建資料庫、使用者和權限
echo " "
echo "請輸入要設定的資料庫密碼:"
read ANS
echo " "
echo "###########################################################"
echo "######### MariaDB 資料庫:librenms 密碼:$ANS #################"
echo "###########################################################"
mysql -uroot -e "CREATE DATABASE librenms CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
mysql -uroot -e "CREATE USER 'librenms'@'localhost' IDENTIFIED BY '$ANS';"
mysql -uroot -e "GRANT ALL PRIVILEGES ON librenms.* TO 'librenms'@'localhost';"
mysql -uroot -e "FLUSH PRIVILEGES;"
##### 在配置文件的 [mysqld] 部分添加以下內容: ####
## innodb_file_per_table=1
## lower_case_table_names=0
sed -i '/mysqld]/ a lower_case_table_names=0' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/mysqld]/ a innodb_file_per_table=1' /etc/mysql/mariadb.conf.d/50-server.cnf
##### 重新啟動 mysql 並啟用開機自動運行
systemctl restart mariadb
systemctl enable mariadb
### 配置並啟動 PHP-FPM ####
## 新功能於 20.04 引入並在 22.04 中保留##
cp /etc/php/8.3/fpm/pool.d/www.conf /etc/php/8.3/fpm/pool.d/librenms.conf
# vi /etc/php/8.3/fpm/pool.d/librenms.conf
#line 4
sed -i 's/\[www\]/\[librenms\]/' /etc/php/8.3/fpm/pool.d/librenms.conf
# line 23
sed -i 's/user = www-data/user = librenms/' /etc/php/8.3/fpm/pool.d/librenms.conf
# line 24
sed -i 's/group = www-data/group = librenms/' /etc/php/8.3/fpm/pool.d/librenms.conf
# line 36
sed -i 's/listen = \/run\/php\/php8.3-fpm.sock/listen = \/run\/php-fpm-librenms.sock/' /etc/php/8.3/fpm/pool.d/librenms.conf
#### 在以下文件中將時區更改為 America/[City]：####
# /etc/php/8.3/fpm/php.ini
# /etc/php/8.3/cli/php.ini
echo "正在將時區設置為 $TZ 於 /etc/php/8.3/fpm/php.ini 和 /etc/php/8.3/cli/php.ini，如有需要請更改。"
echo "更改為 $TZ"
echo "################################################################################"
echo " "
# 第 969 行新增
sed -i "/;date.timezone =/ a date.timezone = $TZ" /etc/php/8.3/fpm/php.ini
# 第 969 行新增
sed -i "/;date.timezone =/ a date.timezone = $TZ" /etc/php/8.3/cli/php.ini
echo "????????????????????????????????????????????????????????????????????????????????"
read -p "請在另一個終端機中檢查更改，然後按 [Enter] 繼續..."
echo " "
### 重新啟動 PHP-fpm ###
systemctl restart php8.3-fpm
#### 配置 NGINX 網頁伺服器 ####
### 創建 .conf 文件 ###
echo "################################################################################"
echo "將伺服器名稱更改為當前 IP，除非名稱可解析 /etc/nginx/conf.d/librenms.conf"
echo "################################################################################"
echo "輸入主機名 [x.x.x.x or your.domain.com]: "
read HOSTNAME
echo "server {"> /etc/nginx/conf.d/librenms.conf
echo " listen      80;" >>/etc/nginx/conf.d/librenms.conf
echo " server_name $HOSTNAME;" >>/etc/nginx/conf.d/librenms.conf
echo ' root        /opt/librenms/html;' >>/etc/nginx/conf.d/librenms.conf
echo " index       index.php;" >>/etc/nginx/conf.d/librenms.conf
echo " " >>/etc/nginx/conf.d/librenms.conf
echo " charset utf-8;" >>/etc/nginx/conf.d/librenms.conf
echo " gzip on;" >>/etc/nginx/conf.d/librenms.conf
echo " gzip_types text/css application/javascript text/javascript application/x-javascript image/svg+xml \
text/plain text/xsd text/xsl text/xml image/x-icon;" >>/etc/nginx/conf.d/librenms.conf
echo ' location / {' >>/etc/nginx/conf.d/librenms.conf
echo '  try_files $uri $uri/ /index.php?$query_string;' >>/etc/nginx/conf.d/librenms.conf
echo " }" >>/etc/nginx/conf.d/librenms.conf
echo ' location ~ [^/]\.php(/|$) {' >>/etc/nginx/conf.d/librenms.conf
echo '  fastcgi_pass unix:/run/php-fpm-librenms.sock;' >>/etc/nginx/conf.d/librenms.conf
echo '  fastcgi_split_path_info ^(.+\.php)(/.+)$;' >>/etc/nginx/conf.d/librenms.conf
echo "  include fastcgi.conf;" >>/etc/nginx/conf.d/librenms.conf
echo " }" >>/etc/nginx/conf.d/librenms.conf
echo ' location ~ /\.(?!well-known).* {' >>/etc/nginx/conf.d/librenms.conf
echo "  deny all;" >>/etc/nginx/conf.d/librenms.conf
echo " }" >>/etc/nginx/conf.d/librenms.conf
echo "}" >>/etc/nginx/conf.d/librenms.conf
##### 移除預設的 Nginx Web連結 #####
rm /etc/nginx/sites-enabled/default
systemctl restart nginx
systemctl restart php8.3-fpm
#### 啟用 LNMS 命令補全 ####
ln -s /opt/librenms/lnms /usr/bin/lnms
cp /opt/librenms/misc/lnms-completion.bash /etc/bash_completion.d/
### 配置 snmpd
cp /opt/librenms/snmpd.conf.example /etc/snmp/snmpd.conf
### 編輯文字 "RANDOMSTRINGGOESHERE" 並設定自己的社群字串。
echo "我們需要更改 SNMP 管理代理存取的密碼 (社群字串 community string)"
echo "請輸入此伺服器的社群字串 [例如：public]: "
read ANS
sed -i 's/RANDOMSTRINGGOESHERE/$ANS/g' /etc/snmp/snmpd.conf
######## 獲取標準 MIBs
curl -o /usr/bin/distro https://raw.githubusercontent.com/librenms/librenms-agent/master/snmp/distro
chmod +x /usr/bin/distro
#### 啟用 SNMP 開機自動啟動 ####
systemctl enable snmpd
systemctl restart snmpd
##### 設置 Cron 設定
cp /opt/librenms/dist/librenms.cron /etc/cron.d/librenms
#### 啟用排程器
cp /opt/librenms/dist/librenms-scheduler.service /opt/librenms/dist/librenms-scheduler.timer /etc/systemd/system/
systemctl enable librenms-scheduler.timer
systemctl start librenms-scheduler.timer

##### 設置 logrotate 配置
cp /opt/librenms/misc/librenms.logrotate /etc/logrotate.d/librenms
######
echo " "
echo "###############################################################################################"
echo "在您的網頁瀏覽器中開啟 http://$HOSTNAME/install 以完成安裝。"
echo "###############################################################################################"
#END#
