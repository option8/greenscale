#!/bin/bash

convert animation.gif frame%05d.gif

convert frame*.gif -compress none -scale 56x100%  -scale 40x48\! -colorspace Gray -colors 16 -depth 8 -auto-level -evaluate divide 17 %d.gray

for file in *.gray
do
	cat "$file" | python -u ../greenscale.py >> data.bin
done
