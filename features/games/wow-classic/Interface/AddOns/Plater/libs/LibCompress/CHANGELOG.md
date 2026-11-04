# r87

## Deflate family, through C_EncodingUtil

- `CompressDeflate`, `CompressZlib`, `CompressGzip` and the matching `Decompress` functions, using header codes 4, 5 and 6.
- These need `C_EncodingUtil`, available on Dragonflight and later clients. `HasZlibCodecs()` tells you whether the current client provides it; the library falls back to the pure Lua codecs when it does not.
- Malformed or truncated input never raises an error. A damaged stream returns nil, so a corrupt message from another player cannot break your add-on.

## Capability negotiation

- `LibCompress:Compress(data[, capability[, filter[, level]]])` and the new `LibCompress.COMPRESS_CAPABILITY` constant.
- Capability 1, the default, is what r83 and r86 can decode: store, LZW and Huffman without a prefilter. Streams stay compatible with every released version of this library.
- Capability 2 additionally allows the deflate family and the prefilters. Exchange `COMPRESS_CAPABILITY` with your communication partner and pass the lowest of the two.
- `Compress(data, "max")` uses everything this client supports, which is what you want for data that is only read back locally.
- Asking for a prefilter or a compression level the target capability cannot decode is an error instead of a silent downgrade, so a wrong assumption shows up immediately.

## Prefilters

- `FilterSub`/`UnfilterSub` (byte delta) and `FilterRLE`/`UnfilterRLE`, selectable as `"sub"`, `"rle"` or `"auto"` in `Compress` and in the standalone LZW and Huffman coders.
- The prefilter in use is recorded in the header, and every decoder reverses its own prefilter, so `Decompress` remains a single dispatch on the header byte.
- On text and image data a prefilter typically halves the result on top of LZW or Huffman, and it turns poorly compressible data into well compressible data.

## Checksums

- `fcs16String` and `fcs32String`, plus the `fcs16init/update/final` and `fcs32init/update/final` sequences for data that arrives in pieces.
- `fcs16Hex` and `fcs32Hex` return a fixed width printable form, useful as a message id on the addon channel.

## Encoding for chat channels

- `GetLoggedEncodeTable(reservedChars, escapeChars, mapChars)` builds an encoder for data that has to survive a logged chat channel: printable ASCII only, no NUL bytes and no pipe escapes.

## Fixes

- `CompressLZW("")` no longer errors.
- LZW and Huffman now set the header correctly when they fall back to storing data uncompressed, so `Decompress` picks the right decoder.
- The library version is now a plain LibStub minor (90087) instead of being derived from the SVN revision.
