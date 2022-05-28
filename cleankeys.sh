#!/bin/sh
pth="/home/templates/.ssh/authorized_keys"
cmd='/^#/ {
			e=substr($0,2);
			"date +%s" | getline d;
			cmd="echo $(( " e " > " d " ))";
			cmd | getline o;
			if(o=="1"){print;c=1;next}
		}
	c==1 {c=0; print $0}'

awk "$cmd" $pth | tee $pth