import 'dart:typed_data';

/// Delay, in hundredths of a second, written over a frame that declares none.
const int _gifDefaultDelay = 0x0A;

/// Walks the GIF block structure and rewrites the delay field of every Graphic
/// Control Extension that declares a delay of 0, in place.
///
/// This parses the container rather than scanning every offset for the byte
/// sequence `21 F9 04`: that sequence also occurs by chance inside LZW frame
/// data, and writing a delay over a false positive corrupts the frame stream
/// from that point on. Anything that doesn't parse as a GIF is returned
/// untouched rather than guessed at.
///
/// Only block headers are read — compressed payloads are skipped by arithmetic
/// — so this touches a few hundred bytes regardless of file size.
///
/// Kept free of Flutter imports so it stays runnable on the plain Dart VM.
Uint8List rewriteZeroDelayGifFrames(Uint8List image) {
  // Header (6 bytes) + Logical Screen Descriptor (7 bytes).
  if (image.length < 13) return image;
  if (image[0] != 0x47 || image[1] != 0x49 || image[2] != 0x46) return image; // "GIF"

  int i = 13;
  final int screenPacked = image[10];
  if (screenPacked & 0x80 != 0) {
    i += _gifColorTableSize(screenPacked); // global color table
  }

  while (i < image.length) {
    final int blockType = image[i];

    if (blockType == 0x3B) break; // trailer

    if (blockType == 0x21) {
      // Extension block: introducer, label, then a sub-block chain.
      if (i + 2 >= image.length) return image;
      final int label = image[i + 1];
      final int blockSizeIndex = i + 2;

      if (label == 0xF9) {
        // Graphic Control Extension. Sub-block is
        // [size=4][packed][delay lo][delay hi][transparent index].
        final int delayLo = blockSizeIndex + 2;
        final int delayHi = blockSizeIndex + 3;
        if (image[blockSizeIndex] >= 4 && delayHi < image.length) {
          if (image[delayLo] == 0x00 && image[delayHi] == 0x00) {
            image[delayLo] = _gifDefaultDelay;
          }
        }
      }

      final int next = _skipGifSubBlocks(image, blockSizeIndex);
      if (next < 0) return image;
      i = next;
    } else if (blockType == 0x2C) {
      // Image Descriptor: 10 bytes, optional local color table, LZW code size,
      // then the frame's sub-block chain.
      if (i + 9 >= image.length) return image;
      final int imagePacked = image[i + 9];
      int p = i + 10;
      if (imagePacked & 0x80 != 0) {
        p += _gifColorTableSize(imagePacked);
      }
      p += 1; // LZW minimum code size
      if (p >= image.length) return image;

      final int next = _skipGifSubBlocks(image, p);
      if (next < 0) return image;
      i = next;
    } else {
      // Not a block type we recognise — the structure isn't what we expect, so
      // stop rather than write into a position we can't account for.
      return image;
    }
  }

  return image;
}

/// Byte length of the color table described by a GIF packed field.
int _gifColorTableSize(int packed) => 3 * (1 << ((packed & 0x07) + 1));

/// Skips the sub-block chain starting at [start], returning the index just past
/// its terminator, or -1 if the chain runs off the end of the buffer.
int _skipGifSubBlocks(Uint8List image, int start) {
  int i = start;
  while (i < image.length) {
    final int size = image[i];
    if (size == 0) return i + 1;
    i += size + 1;
  }
  return -1;
}
