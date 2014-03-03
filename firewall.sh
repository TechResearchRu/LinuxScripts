#!/bin/bash

PATH=/usr/sbin:/bin:/sbin

# КОНФИГУРАЦИЯ СКРИПТА
EXTIF="eth1" #внешний интерфейс
INTIF="eth0" #внутренний интерфейс

TCPFORWARD="6100,5003,6000,443,5090"
UDPFORWARD="5003,5090,6000,30000:30015"
# адрес АТС
FORWARDIP="192.168.2.100" 
# Список портов, открытых на сервере для внешнего мира
SERVICES="22,1723"
# порты, по которым пользователи могут вылазить в интернет
OPENPORTS="80,22,443,5190,995,465,5222,5223,20,21,8888,8086" 
FW="iptables"

#Фильтрация форварда
add_white_ip() {
	$FW -A FORWARD -s $1 -d $FORWARDIP -i $EXTIF -o $INTIF -j ACCEPT
}


prepare() {
	echo 1 > /proc/sys/net/ipv4/ip_forward
	modprobe ip_nat_irc ip_nat_ftp iptable_nat ip_conntrack_irc ip_conntrack_ftp ip_conntrack ip_tables
	$FW -t filter -F
	$FW -t nat -F
	$FW -t mangle -F
	$FW -X
}

filter() {
	# INPUT
	$FW -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
	$FW -A INPUT -m state --state NEW -i ! $EXTIF -j ACCEPT
	$FW -A INPUT -p icmp --icmp-type 8 -j ACCEPT
	$FW -A INPUT -p tcp -m tcp -m multiport -i $EXTIF --dports $SERVICES -j ACCEPT 
	$FW -A INPUT -i $INTIF -j ACCEPT 
	$FW -P INPUT DROP
	
	# FORWARD
	$FW -A FORWARD -i $EXTIF -o $INTIF -m state --state ESTABLISHED,RELATED -j ACCEPT
	$FW -A FORWARD -i $INTIF -o $EXTIF -m state --state ESTABLISHED,RELATED -j ACCEPT
	$FW -A FORWARD -s $FORWARDIP -i $INTIF -o $EXTIF -j ACCEPT
	$FW -A FORWARD -d $FORWARDIP -i $EXTIF -o $INTIF -j ACCEPT
	$FW -A FORWARD -o ppp0 -j ACCEPT
	$FW -A FORWARD -i ppp0 -j ACCEPT
	$FW -P FORWARD DROP
	
	# OUTPUT
	$FW -P OUTPUT ACCEPT
}

nat() {
	# PREROUTING
	$FW -t nat -A PREROUTING -p tcp -i $EXTIF -m multiport --dports $TCPFORWARD -j DNAT --to-destination $FORWARDIP #forward tcp
	$FW -t nat -A PREROUTING -p udp -i $EXTIF -m multiport --dports $UDPFORWARD -j DNAT --to-destination $FORWARDIP #forward udp
	# входящие пакеты с 80 портом с внутрннего интерфейса перенаправляются на прокси
	$FW -t nat -A PREROUTING -i $INTIF -p tcp --dport 80 -j REDIRECT --to-port 3128
	
	# POSTROUTING
	$FW -t nat -A POSTROUTING -o $EXTIF -j MASQUERADE
}


main() {
	prepare	
	filter
	nat
}

main
