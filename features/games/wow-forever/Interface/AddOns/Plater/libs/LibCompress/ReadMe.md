LibCompress is a compression and decompression library implemented entirely in WoW-friendly Lua. It supports the LZW and Huffman algorithms, the deflate based formats offered by Blizzard (raw deflate, zlib and gzip), a byte delta and a run-length prefilter, and it can automatically choose the most efficient combination for your data. One popular usage for this library is to send a compressed table to another player or add-on. Doing this requires additional encoding to remove the \000 characters from the data stream.

Questions, bug reports and feature requests: please create an issue on this project page or e-mail galmok@gmail.com.

# Usage:
## Loading
The library is marked load on demand, so depend on it in your own addon or force load it using:

`LoadAddOn("LibCompress")`

On retail 11.x and later that function lives in the C_AddOns namespace:

`C_AddOns.LoadAddOn("LibCompress")`

Follow it with:

`libc = LibStub:GetLibrary("LibCompress")`

## Compression
Load the library with:

`libc = LibStub:GetLibrary("LibCompress")`

Compress data (must be in string form):

`compressed_data = libc:Compress(data)`

This will try all compression algorithms and return the best compressed result. It is possible to specify a specific compression algorithm like this:

`compressed_data = libc:CompressHuffman(data)`

or

`compressed_data = libc:CompressLZW(data)`

or one of the deflate based algorithms, which need C_EncodingUtil (Dragonflight and later clients):

`compressed_data = libc:CompressDeflate(data)`

`compressed_data = libc:CompressZlib(data)`

`compressed_data = libc:CompressGzip(data)`

Data will either be compressed with the requested algorithm or not at all. Data returned with a prefix byte identifying how it was compressed.

The deflate based calls take an optional compression level. Blizzard exposes three of them: 0 or `"default"`, 1 or `"speed"` (`Enum.CompressionLevel.OptimizeForSpeed`) and 2 or `"size"` (`Enum.CompressionLevel.OptimizeForSize`):

`compressed_data = libc:CompressZlib(data, "size")`

`libc:HasZlibCodecs()` tells you whether the client provides the zlib bindings. If it does not, the three calls above return nil with an error message, while `:Compress()` simply leaves them out and uses LZW and Huffman only.

To decompress the data, simply use this:

`decompressed_data = libc:Decompress(compressed_data)`

Compress and Decompress can return an error and this is signaled by the first returned argument being nil and the second the error message. So checking for that would be appropriate.

## Prefilters
Text compresses well, images and numeric data do not. The two prefilters below do not compress anything by themselves: they move the redundancy around so that the entropy coder can find it, and they are reverted automatically during decompression. They are pure Lua and available on every client.

- `"sub"` - replaces every byte with its difference to the previous byte. Very effective on images, gradients and other slowly changing data.
- `"rle"` - run-length encodes repeated bytes. Effective on flat areas.

Every coder accepts a filter as an extra argument:

`compressed_data = libc:CompressHuffman(data, "sub")`

`compressed_data = libc:CompressZlib(data, "size", "rle")`

and `:Compress()` takes one too:

`compressed_data = libc:Compress(data, 2, "sub")`

Pass `"auto"` instead of a filter name to have the library try none, sub and rle and keep the smallest result:

`compressed_data = libc:Compress(data, 2, "auto")`

`"auto"` costs about three times as much as a single pass. With a good filter selection this is usually invisible for the few kilobytes that go over an addon channel, but Huffman is the slowest codec in this library, so `"auto"` combined with Huffman is not something to run every frame.

The prefilters need capability 2, see below: `libc:Compress(data, "sub")` is an error, not a silent fallback, because the second argument is the capability.

## Capability, older clients and peers
A compressed stream is only useful if the player receiving it can decode it. Your own client having the zlib bindings says nothing about the peer, so `:Compress()` asks you:

`compressed_data = libc:Compress(data)`

With no capability argument that produces a stream every release of this library has ever been able to decode - store, LZW or Huffman, no prefilter. That is the default and it will never change, so adding a codec in a future release cannot break anyone.

`compressed_data = libc:Compress(data, peerCapability)`

The capability of the peer is something only your own protocol can know, so ask for it in your handshake: `libc.COMPRESS_CAPABILITY` is the highest level this library understands, and you send that number to the other side, which replies with its own. Pass the smaller of the two to `:Compress()`.

- capability 1 - store, LZW, Huffman, no prefilter. Every release of this library can decode it.
- capability 2 - adds the deflate family and the prefilters (r87 and newer).

`"max"` selects everything this library can do, which is the right choice when there is no peer at all, for example when writing to SavedVariables.

Streams are self describing: the codec and the prefilter are recorded in the first byte, so `:Decompress()` never needs to be told what was used, and this library decodes streams from any older release.

## Encoding
LibCompress also has the possibility to encode and decode data, preparing it for transmission over the addon channel or chat channel (or a custom encoding). Two forms of encoding is provided:

### Prefix encoding
The first form is prefix-encoding. Basically, reserved characters are replaced with a prefix/escape character followed by the suffix character, i.e. reserved bytes are replaced by a double-byte combination. This is how it is done:

`table, msg = libc:GetEncodeTable(reservedChars, escapeChars,  mapChars)`

reservedChars: The characters in this string will not appear in the encoded data. escapeChars: A string of characters used as escape-characters (don't supply more than needed). #escapeChars >= 1 mapChars: First characters in reservedChars maps to first characters in mapChars. (#mapChars <= #reservedChars)

If table is nil, then msg holds an error message. Otherwise the usage is simple:

`encoded_message = table:Encode(message)`

`message = table:Decode(encoded_message)`

Three predefined setups have been included:

`GetAddonEncodeTable`: Sets up encoding for the addon channel (\000 is encoded)

`GetChatEncodeTable`: Sets up encoding for the chat channel (many bytes encoded, see the function for details)

`GetLoggedEncodeTable`: Sets up encoding for the chat logging channel used by `SendChatMessage(..., "RAWCHAT")`, `C_ChatInfo.SendAddonMessageLogged` and `C_Club.PostMessage`. Everything outside printable ASCII, as well as the `|` of the chat escape sequences, is reserved, so the output is plain printable ASCII and survives being written to a log file and read back. Characters you want to keep out on top of that (the letters of a `|T` texture sequence, for instance) can be passed as reservedChars; give mapChars to have them replaced by a control character instead of an escape pair.

`table, msg = libc:GetLoggedEncodeTable(reservedChars, escapeChars, mapChars)`

escapeChars: characters used as escape characters (don't supply more than needed, defaults to `"~^`"). mapChars: first characters in reservedChars maps to first characters in mapChars. All three arguments are optional.

### 7-bit encoding
This encoding packs bits, not bytes. It puts 7 bits into every byte, enlarging the data by approx 14%. Values from 0 to 127 (both inclusive) are present in the encoded data and therefor has to be prefix-encoded as well. This encoding generates a bit of string trash and should be used with consideration.

Encode data like this:

`encoded_data = libc:Encode7bit(data)`

Decode data like this:

`decoded_data = libc:Decode7bit(encoded_data)`

## Checksum/hash algorithms
LibCompress also provides 2 reasonable fast hash algorithms. They are converted from a C-implementation to lua and are quite fast. The hash value is either 16 bit or 32 bit.

Use like this (data1, data2, data... = string):

`code = libc:fcs16init()`
`code = libc:fcs16update(code, data1)`
`code = libc:fcs16update(code, data2)`
`code = libc:fcs16update(code, data...)`
`code = libc:fcs16final(code)`

data = string fcs16 provides a 16 bit checksum, fcs32 provides a 32 bit checksum.

For the common case of a checksum over one string there are short cuts:

`code = libc:fcs16String(data)` / `code = libc:fcs32String(data)`

A printable form, handy when the checksum has to travel over a chat channel or be shown to the user:

`text = libc:fcs16Hex(data)` / `text = libc:fcs32Hex(data)`

The 32 bit value is the CRC-32 of RFC 1331, the same value as `zlib.crc32` returns, so a checksum can be compared with one computed outside the game.

# Credits
Primary author: Galmok of European Stormrage (Horde), galmok@gmail.com.

Former author: JJSheets (sheets.jeff@gmail.com), who implemented the LZW codec. He is not active with this library.

LibStub is used as the library loader and is pulled in from https://repos.curseforge.com/wow/libstub/trunk when the package is built. It is public domain, written by Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel and joshborke.
