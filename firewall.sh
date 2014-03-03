#!/bin/bash
###################################
#БАЗОВАЯ КОНФИГУРАЦИЯ СКРИПТА
###################################
EXTIF="eth1" #внешний интерфейс сервера
INTIF="eth0" #внутренний интерфейс сервера
TCPFORWARD="6100,5003,6000,443,5090" #пробрасываемые TCP порты
UDPFORWARD="5003,5090,6000,30000:30015" #пробрасываемые UDP порты
FORWARDIP="192.168.2.100" #IP адрес АТС
SERVICES="22,1723" #  Список портов, открытых на сервере для внешнего мира
OPENPORTS="80,22,443,5190,995,465,5222,5223,20,21,8888,8086" # порты, по которым пользователи могут вылазить в интернет
################################################
################################################
#      конец конфигурации скрипта              #
################################################
################################################
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
PATH=/usr/sbin:/bin:/sbin; FW="iptables"; echo 1 > /proc/sys/net/ipv4/ip_forward
modprobe ip_nat_irc ip_nat_ftp iptable_nat ip_conntrack_irc ip_conntrack_ftp ip_conntrack ip_tables #подгрузка модулей
$FW -F;$FW -t nat -F;$FW -t mangle -F;$FW -X;$FW -P FORWARD DROP;$FW -P INPUT DROP #дефолтные правила
#%%%%%%%%%%%%правила для сервера (фаервола)%%%%%%%%%%%%%%%%%%%%
$FW -A INPUT -p icmp --icmp-type 8 -j ACCEPT #разрешить PING сервера
$FW -A INPUT -p tcp -m tcp -m multiport -i $EXTIF --destination-ports $SERVICES -j ACCEPT # со внехи к серверу можно обратиться только по избранным портам
$FW -A INPUT -i $INTIF -j ACCEPT # из локальной сети к серверу можно обращаться по всем портам
$FW -A OUTPUT -j ACCEPT # сервер может вылазить в инет по всем портам
########################################################################

#Разрешить соединения, которые инициированы изнутри (local)
$FW -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
$FW -A INPUT -m state --state NEW -i ! $EXTIF -j ACCEPT
$FW -A FORWARD -i $EXTIF -o $INTIF -m state --state ESTABLISHED,RELATED -j ACCEPT
$FW -A FORWARD -i $INTIF -o $EXTIF -m state --state ESTABLISHED,RELATED -j ACCEPT
#
#Фильтрация форварда
function add_white_ip
{
	$FW -A FORWARD -s $1 -d $FORWARDIP -i $EXTIF -o $INTIF -j ACCEPT

}




$FW -A FORWARD -s $FORWARDIP -i $INTIF -o $EXTIF -j ACCEPT
$FW -A FORWARD -d $FORWARDIP -i $EXTIF -o $INTIF -j ACCEPT
$FW -A FORWARD -j ACCEPT

$FW -A FORWARD  -o ppp0 -j ACCEPT
$FW -A FORWARD  -i ppp0 -j ACCEPT
# Masquerade.
$FW -t nat -A POSTROUTING -o $EXTIF -j MASQUERADE

#forward udp and tcp
$FW -t nat -A PREROUTING -p tcp -i $EXTIF -m multiport --dport $TCPFORWARD -j DNAT --to-destination $FORWARDIP #forward tcp
$FW -t nat -A PREROUTING -p udp -i $EXTIF -m multiport --dport $UDPFORWARD -j DNAT --to-destination $FORWARDIP #forward udp
$FW -t nat -A PREROUTING -i $INTIF -p tcp --dport 80 -j REDIRECT --to-port 3128 # входящие пакеты с 80 портом с внутрннего интерфейса перенаправляются на прокси