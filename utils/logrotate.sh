#!/bin/bash
cd /var/log/dockers
# number of days to keep uncompressed
i=2
dd=$(date -d "-$i days" +"%Y-%m-%d")
while [ -d $dd ]; do 
	cd $dd
	tar -oc * | gzip -9 >../$dd.tgz
	cd ..
	rm -rf ./$dd
	i=$((i+1))
	dd=$(date -d "-$i days" +"%Y-%m-%d")
done

