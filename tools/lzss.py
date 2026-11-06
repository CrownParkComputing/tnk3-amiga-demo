"""Small 4KB-window LZSS codec shared with the native Amiga decoder."""
import struct


def lzss_compress(data):
    out = bytearray()
    index = 0
    while index < len(data):
        flag_position = len(out)
        out.append(0)
        flags = 0
        for bit in range(7, -1, -1):
            if index >= len(data):
                break
            best_length = 2
            best_offset = 0
            max_length = min(18, len(data) - index)
            if max_length >= 3:
                needle = data[index:index + 3]
                position = data.find(needle, max(0, index - 4095), index)
                while position != -1:
                    length = 3
                    while (
                        length < max_length
                        and data[position + length] == data[index + length]
                    ):
                        length += 1
                    if length > best_length:
                        best_length = length
                        best_offset = index - position
                        if length == max_length:
                            break
                    position = data.find(needle, position + 1, index)
            if best_length >= 3:
                code = (best_offset << 4) | (best_length - 3)
                out.extend(struct.pack(">H", code))
                index += best_length
            else:
                flags |= 1 << bit
                out.append(data[index])
                index += 1
        out[flag_position] = flags
    if len(out) & 1:
        out.append(0)
    return struct.pack(">I", len(data)) + out


def lzss_decompress(packed):
    """Independent round-trip check for the assembly decoder's data format."""
    length = struct.unpack_from(">I", packed)[0]
    index = 4
    out = bytearray()
    while len(out) < length:
        flags = packed[index]
        index += 1
        for bit in range(7, -1, -1):
            if len(out) >= length:
                break
            if flags & (1 << bit):
                out.append(packed[index])
                index += 1
            else:
                code = struct.unpack_from(">H", packed, index)[0]
                index += 2
                offset = code >> 4
                assert 1 <= offset <= min(4095, len(out))
                for _ in range((code & 15) + 3):
                    out.append(out[-offset])
    assert len(out) == length
    return bytes(out)
