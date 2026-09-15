#!/usr/bin/env python3
"""Deterministic shader input: smooth start fade across U, soft edges across V."""
import struct,zlib
from pathlib import Path
root=Path(__file__).resolve().parents[1]/'mod/TrajectoryPreview/Textures'
def smooth(t):
    t=max(0,min(1,t));return t*t*(3-2*t)
def chunk(kind,data):
    return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
for name,tint in [('world-arc',(1.0,0.78,0.12)),('world-box',(1.0,0.52,0.08))]:
    rows=[]
    for y in range(64):
        edge=smooth((1-abs(2*y/63-1))/0.65)
        row=bytearray([0])
        for x in range(128):
            alpha=round(255*0.9*edge*smooth((x/127)/0.75))
            row.extend([*(round(255*c) for c in tint),alpha])
        rows.append(row)
    data=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',128,64,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(b''.join(rows),9))+chunk(b'IEND',b'')
    (root/(name+'.png')).write_bytes(data)
