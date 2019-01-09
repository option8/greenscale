#!/bin/bash

convert animation.gif -coalesce frame%02d.gif

convert frame*.gif -resize 640x480 -gravity center -background white -extent 640x480 -compress none -scale 56x100% -resize 40x48\! \
-colorspace Gray -colors 16 -depth 8 -auto-level -evaluate divide 17 %02d.gray


for file in *.gray
do
	cat "$file" | python -u ../greenscale.py >> data.bin
done
