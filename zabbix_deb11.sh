#!/bin/bash                                                      
# ZZZZZZZZZZ  ZZZZZZZZZZ  ZZZZZZZZZZ  ZZZZZZZZZZ  ZZ  ZZ         ZZ
#         ZZ  ZZ      ZZ  ZZ      ZZ  ZZ      ZZ  ZZ   ZZ       ZZ
#        ZZ   ZZ      ZZ  ZZ      ZZ  ZZ      ZZ  ZZ    ZZ     ZZ
#       ZZ    ZZ      ZZ  ZZ      ZZ  ZZ      ZZ  ZZ     ZZ   ZZ
#      ZZ     ZZ      ZZ  ZZ      ZZ  ZZ      ZZ  ZZ      ZZ ZZ
#     ZZ      ZZZZZZZZZZ  ZZZZZZZZ    ZZZZZZZZ    ZZ       ZZZ 
#    ZZ       ZZ      ZZ  ZZ      ZZ  ZZ      ZZ  ZZ      ZZ ZZ
#   ZZ        ZZ      ZZ  ZZ      ZZ  ZZ      ZZ  ZZ     ZZ   ZZ
#  ZZ         ZZ      ZZ  ZZ      ZZ  ZZ      ZZ  ZZ    ZZ     ZZ
# ZZ          ZZ      ZZ  ZZ      ZZ  ZZ      ZZ  ZZ   ZZ       ZZ
# ZZZZZZZZZZ  ZZ      ZZ  ZZZZZZZZ    ZZZZZZZZ    ZZ  ZZ         ZZ
# ====================================#
#
#  Zabbix - 6.0.20  data: 21/08/2023
#  
# ====================================#
#  
#  autor: Rafael Burger de Oliveira
#
# ====================================#
#  
#  Instalando Zabbix
#
# ====================================#
#
# Requerimentos:
# CPU: 4vCPU/8vCPU
# Memoria RAM: 16GB
# HDD/SSD: 350GB
# 
# ====================================#

# Criaçao de usuario
echo "Insira o nome de usuario:"
read user
useradd $user
echo "Insira a senha para o usuario $user: "
read senha

mkdir /home/$user

if [ "$senha" == "" ]
then
    echo "Insira uma senha válida..."
    echo "Senha para $user: "
    read senha
else
    echo "$user":"$senha" | chpasswd
fi

# Correçao de Repositorio
export PATH=$PATH:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
echo "PATH="/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/bin:/usr/local/sbin:/usr/games:/usr/local/games"" >> /etc/environment

# Atualizando
apt update; apt upgrade -y
apt install -y vim nano wget net-tools snmpd snmp

# Configurando Firewall
apt-get install -y nftables
echo "
#!/usr/sbin/nft -f

flush ruleset                                                                    
                                                                                 
table inet firewall {
                                                                                 
    chain inbound_ipv4 {

        icmp type echo-request limit rate 5/second accept      
    }

    chain inbound_ipv6 {

        icmpv6 type { nd-neighbor-solicit, nd-router-advert, nd-neighbor-advert } accept                                                                         
        icmpv6 type echo-request limit rate 5/second accept
    }

    chain inbound {                                                              
        type filter hook input priority 0; policy drop;
        ct state vmap { established : accept, related : accept, invalid : drop } 
        iifname lo accept
        meta protocol vmap { ip : jump inbound_ipv4, ip6 : jump inbound_ipv6 }
        tcp dport { 10050, 10051, 3000, 80, 443, 22, 53 } accept
        udp dport { 10050, 10052, 161, 162, 53 } accept

    }                                                                            
                                                                                 
    chain forward {                                                                              
        type filter hook forward priority 0; policy drop;                        
    }                                                                            
                                                                                 
}
" > /etc/nftables.conf
systemctl start nftables
systemctl enable nftables

# Instalando o LNMP (Linux Nginx MariaDB PHP)
apt install -y nginx
systemctl enable nginx

apt install -y mariadb-server
systemctl start mariadb
systemctl enable mariadb
echo -e "y\nadmin\nadmin\ny\ny\ny\ny" | mysql_secure_installation

apt install -y php php-fpm php-curl php-cli php-zip php-mysql php-xml

# Instalando Zabbix Server
# Baixando Repositorio
wget https://repo.zabbix.com/zabbix/6.0/debian/pool/main/z/zabbix-release/zabbix-release_6.0-4+debian11_all.deb
dpkg -i zabbix-release_6.0-4+debian11_all.deb
apt update -y

# Instalando Zabbix server, Frontend, Agent
apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-nginx-conf zabbix-sql-scripts zabbix-agent

# Configurando o Banco de dados
echo "Insira a senha para o usuario root (MySQL):"
read senhasql

if [ "$senhasql" == "" ]
then
    echo "Insira novamente a senha."
    read senhasql
    mysql -uroot -p$senhasql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$senhasql';"
    mysql -uroot -p$senhasql -e "create database zabbixdb character set utf8mb4 collate utf8mb4_bin;"
    mysql -uroot -p$senhasql -e "create user zabbixuser@localhost identified by '$senhasql';"
    mysql -uroot -p$senhasql -e "grant all privileges on zabbixdb.* to zabbixuser@localhost;"
    mysql -uroot -p$senhasql -e "flush privileges"
    mysql -uroot -p$senhasql -e "set global log_bin_trust_function_creators = 1;"
else
    mysql -uroot -p$senhasql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$senhasql';"
    mysql -uroot -p$senhasql -e "create database zabbixdb character set utf8mb4 collate utf8mb4_bin;"
    mysql -uroot -p$senhasql -e "create user zabbixuser@localhost identified by '$senhasql';"
    mysql -uroot -p$senhasql -e "grant all privileges on zabbixdb.* to zabbixuser@localhost;"
    mysql -uroot -p$senhasql -e "flush privileges"
    mysql -uroot -p$senhasql -e "set global log_bin_trust_function_creators = 1;"
fi

zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbixuser -p$senhasql zabbixdb

mysql -uroot -p$senhasql -e "set global log_bin_trust_function_creators = 0;"



# Alterando parametros
sed -i 's/# DBPassword=/DBPassword='$senhasql'/' /etc/zabbix/zabbix_server.conf
sed -i 's/DBName=zabbix/DBName=zabbixdb/' /etc/zabbix/zabbix_server.conf
sed -i 's/DBUser=zabbix/DBUser=zabbixuser/' /etc/zabbix/zabbix_server.conf

# Configurando PHP para o Zabbix Frontend
sed -i 's/#        listen          8080;/         listen          8080;/' /etc/zabbix/nginx.conf
sed -i 's/#        server_name     example.com;/        server_name     example.com;/' /etc/zabbix/nginx.conf
sed -i 's/80 default_server/82 default_server/' /etc/nginx/sites-available/default
sed -i 's/         listen          8080;/         listen          80;/' /etc/nginx/conf.d/zabbix.conf

# Reinicializando serviços e processos
systemctl restart zabbix-server zabbix-agent nginx php7.4-fpm
systemctl enable zabbix-server zabbix-agent nginx php7.4-fpm

cp /etc/issue /etc/issue.bkp
echo "\S" > /etc/issue
echo "Kernel \r on an \m" > /etc/issue
echo "                                                     
ZZZZZZZZZZ  ZZZZZZZZZZ  ZZZZZZZZZZ  ZZZZZZZZZZ  ZZ  ZZ         ZZ
        ZZ  ZZ      ZZ  ZZ      ZZ  ZZ      ZZ  ZZ   ZZ       ZZ
       ZZ   ZZ      ZZ  ZZ      ZZ  ZZ      ZZ  ZZ    ZZ     ZZ
      ZZ    ZZ      ZZ  ZZ      ZZ  ZZ      ZZ  ZZ     ZZ   ZZ
     ZZ     ZZ      ZZ  ZZ      ZZ  ZZ      ZZ  ZZ      ZZ ZZ
    ZZ      ZZZZZZZZZZ  ZZZZZZZZ    ZZZZZZZZ    ZZ       ZZZ 
   ZZ       ZZ      ZZ  ZZ      ZZ  ZZ      ZZ  ZZ      ZZ ZZ
  ZZ        ZZ      ZZ  ZZ      ZZ  ZZ      ZZ  ZZ     ZZ   ZZ
 ZZ         ZZ      ZZ  ZZ      ZZ  ZZ      ZZ  ZZ    ZZ     ZZ
ZZ          ZZ      ZZ  ZZ      ZZ  ZZ      ZZ  ZZ   ZZ       ZZ
ZZZZZZZZZZ  ZZ      ZZ  ZZZZZZZZ    ZZZZZZZZ    ZZ  ZZ         ZZ
" > /etc/issue

systemctl list-unit-files --type service | grep zabbix
systemctl list-unit-files --type service | grep nginx
systemctl list-unit-files --type service | grep mariadb
systemctl list-unit-files --type service | grep nftables

# Instalando MIBs
echo "deb http://deb.debian.org/debian/ buster main contrib non-free" >> /etc/apt/sources.list
echo "deb http://deb.debian.org/debian/ buster-updates main contrib non-free" >> /etc/apt/sources.list
echo "deb http://security.debian.org/debian-security buster/updates main contrib non-free" >> /etc/apt/sources.list
apt-get update -y
apt-get install -y snmp-mibs-downloader

# Finalizaçao
echo "Acessar via web no IP"



