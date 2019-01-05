import sys

data = sys.stdin.read()
mybytearray=bytearray(data)

import struct

#output = open('output.bin', 'wb')

for row in range(48/2):  # because we to 2 rows at a time
 for x in range(40):  
    nibble1 = mybytearray[2*row*40 + x]
    nibble2 = mybytearray[(2*row + 1)*40 + x] * 16
    pixel = nibble1+nibble2
    pixel = struct.pack("B", pixel)
    sys.stdout.write(pixel)
