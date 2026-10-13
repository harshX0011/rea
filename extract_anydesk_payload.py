"""Statically extract the LZMA-packed inner PE from AnyDesk.exe (9.7.3 loader layout).

Loader facts (from Ghidra, FUN_004036a5): LZMA props = 5 bytes at VA 0x210a000,
compressed data follows at 0x210a005, packed size 0x7dc26d, unpacked size 0x1ce4400.
Before decoding, FUN_004033f4 XORs props+data with an LCG keystream (seed 0x8fa).
"""
import hashlib
import lzma
import struct
import sys

IMAGE_BASE_EXPECTED = 0x400000
PROPS_VA, PACKED_SIZE, UNPACKED_SIZE = 0x210A000, 0x7DC26D, 0x1CE4400


def va_to_offset(pe: bytes, va: int) -> int:
    e = struct.unpack_from("<I", pe, 0x3C)[0]
    nsec, optsz = struct.unpack_from("<HH", pe, e + 6)[0], struct.unpack_from("<H", pe, e + 20)[0]
    base = struct.unpack_from("<I", pe, e + 24 + 28)[0]
    assert base == IMAGE_BASE_EXPECTED, f"unexpected image base {base:#x}"
    rva = va - base
    for i in range(nsec):
        h = e + 24 + optsz + 40 * i
        vsize, sva, rsize, rptr = struct.unpack_from("<IIII", pe, h + 8)
        if sva <= rva < sva + max(vsize, rsize):
            assert rva - sva + 5 + PACKED_SIZE <= rsize, "payload runs past section"
            return rptr + rva - sva
    raise ValueError(f"VA {va:#x} not in any section")


def decrypt(buf: bytes, seed: int = 0x8FA) -> bytes:
    # FUN_004033f4: state = state*1664525 + 1013904223; byte ^= (state >> 12) & 0xff
    out, s = bytearray(buf), seed
    for i in range(len(out)):
        s = (s * 0x19660D + 0x3C6EF35F) & 0xFFFFFFFF
        out[i] ^= (s >> 12) & 0xFF
    return bytes(out)


def extract(src: str, dst: str) -> bytes:
    pe = open(src, "rb").read()
    off = va_to_offset(pe, PROPS_VA)
    blob = decrypt(pe[off : off + 5 + PACKED_SIZE])
    props, packed = blob[:5], blob[5:]
    # .lzma "alone" container = 5 props bytes + 8-byte LE unpacked size + raw stream.
    out = lzma.decompress(props + struct.pack("<Q", UNPACKED_SIZE) + packed, format=lzma.FORMAT_ALONE)
    assert len(out) == UNPACKED_SIZE, f"got {len(out):#x} bytes, want {UNPACKED_SIZE:#x}"
    assert out[:2] == b"MZ" and out[struct.unpack_from("<I", out, 0x3C)[0] :][:4] == b"PE\0\0", "not a PE"
    open(dst, "wb").write(out)
    return out


if __name__ == "__main__":
    out = extract(sys.argv[1], sys.argv[2])
    print(f"wrote {len(out):,} bytes  sha256={hashlib.sha256(out).hexdigest()}")
