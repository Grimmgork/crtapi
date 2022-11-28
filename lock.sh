#!/bin/bash
exec 4<$1
flock -x 4
read -p ""
exec 4<&-