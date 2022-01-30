#!/bin/bash

# 1 - вместо Composite, fan2, CPUTIN подставляем свои значения из вывода команды sensors
sensors_res=$(
sensors |\
`#фильтруем строки` \
egrep "(Composite|fan2|CPUTIN)" |
sed \
`#переводим значения` \
-e "s/Composite/Температура NVME/"  \
-e "s/fan2/Скорость вентилятора/"  \
-e "s/CPUTIN/Температура CPU/"  \
`#убираем хлам в скобках и после` \
-e "s/(.*).*//" \
`#убираем пробелы после двоеточий` \
-e  "s/:\s*/: /"  \
`#форматируем выхлоп в key:val` \
-e "s/\(.*\):[^0-9]*\([0-9.]\+\)\s*\(.*\)/\1(\3): \2/" \
`#пробелы перед скобками` \
-e "s/\s*)/)/"
)

#2 - вместо /dev/nvme0 подставляем свое
smart_res=$(
smartctl -a /dev/nvme0 |\
`#фильтруем строки` \
egrep "(Percentage Used|Data Units Written)" |
sed \
`#переводим значения` \
-e "s/Percentage Used/Износ/"  \
-e "s/Data Units Written/Кол-во записей/"  \
`#убираем пробелы после двоеточий` \
-e  "s/:\s*/: /"  \
`#оставим только в квадратных скобках` \
-e  "s/\(.*\):.*\[\(.*\)\]/\1: \2 /"  \
`#форматируем выхлоп в key:val` \
-e "s/\(.*\):[^0-9]*\([0-9.]\+\)\s*\(.*\)/\1(\3): \2/" \
`#пробелы перед скобками` \
-e "s/\s*)/)/"
)



ram_res=$(
free -m | grep "Mem:" | awk '{print "RAM Usage(%): "$3/$2*100}'
)


# если дисков/разделов несколько, то команд будет несколько для каждого отдельно
ssd_res=$(
df -h | egrep '/$' | awk '{print "Заполнение диска: "$5}'
)

cpu_res=$(
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq \
|sort -r|awk '{print "Частота процессора(Ghz): "$1/1000000}'\
|head -1
)

ping_res=$(
ping -q -c1 8.8.8.8 | grep avg |awk -v FS="/" '{print "Ping(ms): "$5}'
)

echo "$sensors_res"
echo "$smart_res"
echo "$ram_res"
echo "$ssd_res"
echo "$cpu_res"
echo "$ping_res"
