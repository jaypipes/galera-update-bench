#!/bin/bash

PROCESSES="3 6" # number of processes
NETWORKS="24 16" # number of networks

for network in `echo $NETWORKS`
do
  for process in `echo $PROCESSES`
  do
    sfu="sfu_""$process""_""$network"
    cas="cas_""$process""_""$network"

    echo $sfu
    echo $cas

    python test.py --processes=$process --netsize=$network --db 'mysql://root:@10.0.3.135:3306/test_db' 'mysql://root:@10.0.3.195:3306/test_db' 'mysql://root:@10.0.3.222:3306/test_db' > $sfu
    python test.py --processes=$process --netsize=$network --db 'mysql://root:@10.0.3.135:3306/test_db' 'mysql://root:@10.0.3.195:3306/test_db' 'mysql://root:@10.0.3.222:3306/test_db' --cas > $cas
  done
done


