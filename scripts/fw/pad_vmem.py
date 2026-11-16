#!/usr/bin/env python3
"""Pad a firmware VMEM image to the full RAM depth with zero words.

Usage: pad_vmem.py <image.vmem> [depth_words=4096]

Why: on the FPGA every block RAM word that the image does not specify is
zero. A 4-state simulator leaves such words unknown (X). The Ibex prefetcher
reads one word past the last instruction, so an X there poisons the core in
XSim although the hardware is unaffected. Padding makes simulation and
hardware memory contents identical. The image is rewritten in place as one
word per line, starting at word address 0.
"""
import re
import sys


def main():
    path = sys.argv[1]
    depth = int(sys.argv[2]) if len(sys.argv) > 2 else 4096
    text = open(path).read()
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    text = re.sub(r"//[^\n]*", " ", text)
    mem = [0] * depth
    addr = 0
    used = 0
    for tok in text.split():
        if tok.startswith("@"):
            addr = int(tok[1:], 16)
            continue
        if addr >= depth:
            raise SystemExit("%s: word address 0x%X exceeds depth %d" % (path, addr, depth))
        mem[addr] = int(tok, 16)
        addr += 1
        used += 1
    with open(path, "w") as out:
        for word in mem:
            out.write("%08X\n" % word)
    print("%s: %d words specified, padded to %d" % (path, used, depth))


if __name__ == "__main__":
    main()
