#!/bin/bash

base_url="http://localhost:9090/jolokia"
memory_url="${base_url}/read/java.lang:type=Memory/HeapMemoryUsage"
used=`wget -q -O - "${memory_url}/used" | sed 's/^.*"value":"\([0-9]*\)".*$/\1/'`
max=`wget -q -O - "${memory_url}/max" | sed 's/^.*"value":"\([0-9]*\)".*$/\1/'`
usage=$((${used}*100/${max}))
if [ $usage -gt 5 ]; then 
  echo "Memory exceeds 80% (used: $used / max: $max = ${usage}\%)";
  exit 1;
else 
  exit 0;
fi
