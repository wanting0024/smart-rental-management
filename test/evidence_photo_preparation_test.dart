import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:image/image.dart' as img;
import 'package:rental_app_demo/services/backend/evidence_photo_preparation.dart';

void main() {
  img.Image source(int width, int height) {
    final image = img.Image(width: width, height: height, numChannels: 4);
    img.fill(image, color: img.ColorRgba8(60, 140, 200, 255));
    return image;
  }

  test(
      'actual pixels are resized without cropping and output fits the byte limit',
      () {
    final image = source(2400, 1800);
    final bytes = img.encodePng(image);
    final photo = prepareEvidencePhotoSync(bytes);
    final decoded = img.decodeJpg(photo.bytes)!;
    expect(decoded.width, 1600);
    expect(decoded.height, 1200);
    expect(
      photo.bytes.length,
      lessThanOrEqualTo(EvidencePhotoPolicy.maxOutputBytes),
    );
    expect(photo.width, decoded.width);
    expect(photo.height, decoded.height);
    expect(() => photo.bytes[0] = 1, throwsUnsupportedError);
  });

  test(
      'small images are not enlarged and transparent pixels use a white background',
      () {
    final image = source(16, 8);
    img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));
    final photo = prepareEvidencePhotoSync(img.encodePng(image));
    final decoded = img.decodeJpg(photo.bytes)!;
    expect(decoded.width, 16);
    expect(decoded.height, 8);
    expect(decoded.getPixel(0, 0).r, greaterThan(245));
    expect(decoded.getPixel(0, 0).g, greaterThan(245));
    expect(decoded.getPixel(0, 0).b, greaterThan(245));
  });

  test('JPEG EXIF orientation is baked once and private metadata is not copied',
      () {
    final image = source(80, 40);
    image.exif.imageIfd.orientation = 6;
    image.exif.imageIfd[0x010e] = img.IfdValueAscii('PRIVATE_CAMERA_COMMENT');
    image.exif.gpsIfd[1] = img.IfdValueAscii('N');
    final photo = prepareEvidencePhotoSync(img.encodeJpg(image, quality: 95));
    final decoded = img.decodeJpg(photo.bytes)!;
    expect(decoded.width, 40);
    expect(decoded.height, 80);
    expect(decoded.exif.isEmpty, isTrue);
    expect(
      latin1.decode(photo.bytes).contains('PRIVATE_CAMERA_COMMENT'),
      isFalse,
    );
  });

  test('PNG text metadata is stripped and output is deterministic', () {
    final image = source(32, 24)..textData = {'Comment': 'PRIVATE_PNG_COMMENT'};
    final bytes = img.encodePng(image);
    final first = prepareEvidencePhotoSync(bytes);
    final second = prepareEvidencePhotoSync(bytes);
    expect(first.bytes, second.bytes);
    expect(latin1.decode(first.bytes).contains('PRIVATE_PNG_COMMENT'), isFalse);
  });

  test('invalid, corrupt, unsupported and oversized inputs are rejected', () {
    for (final bytes in [
      Uint8List(0),
      Uint8List.fromList([255, 216, 255]),
      Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1]),
      Uint8List.fromList(utf8.encode('GIF89a')),
      Uint8List(EvidencePhotoPolicy.maxInputBytes + 1),
    ]) {
      expect(
        () => prepareEvidencePhotoSync(bytes),
        throwsA(isA<PhotoPreparationException>()),
      );
    }
  });

  test('animated PNG is not silently reduced to one frame', () {
    final animation = source(8, 8)..addFrame(source(8, 8));
    final bytes = img.encodePng(animation, singleFrame: false);
    expect(
      () => prepareEvidencePhotoSync(bytes),
      throwsA(isA<PhotoPreparationException>()),
    );
  });

  test('large declared PNG dimensions are rejected before pixel allocation',
      () {
    final bytes = img.encodePng(source(2, 2));
    final view = ByteData.sublistView(bytes);
    view.setUint32(16, 20000);
    view.setUint32(20, 20000);
    // CRC need not be trusted: a malformed or over-budget header must fail.
    expect(
      () => prepareEvidencePhotoSync(bytes),
      throwsA(isA<PhotoPreparationException>()),
    );
  });

  test('asynchronous preparation returns real decodable output', () async {
    final bytes = img.encodeJpg(source(320, 300), quality: 95);
    final photo = await prepareEvidencePhoto(bytes);
    expect(img.decodeJpg(photo.bytes)!.width, 320);
    expect(photo.inputBytes, bytes.length);
  });

  test(
      'platform asynchronous path resizes a large PNG to the same output limits',
      () async {
    final bytes = img.encodePng(source(1800, 900));
    final photo = await prepareEvidencePhoto(bytes);
    final decoded = img.decodeJpg(photo.bytes)!;
    expect(decoded.width, 1600);
    expect(decoded.height, 800);
    expect(
      photo.bytes.length,
      lessThanOrEqualTo(EvidencePhotoPolicy.maxOutputBytes),
    );
  });

  test('platform asynchronous path rotates once and removes GPS and comments',
      () async {
    final image = source(80, 40);
    image.exif.imageIfd.orientation = 6;
    image.exif.imageIfd[0x010e] = img.IfdValueAscii('PRIVATE_COMMENT');
    image.exif.gpsIfd[1] = img.IfdValueAscii('N');
    final photo = await prepareEvidencePhoto(img.encodeJpg(image, quality: 95));
    final decoded = img.decodeJpg(photo.bytes)!;
    expect(decoded.width, 40);
    expect(decoded.height, 80);
    expect(decoded.exif.isEmpty, isTrue);
    expect(latin1.decode(photo.bytes).contains('PRIVATE_COMMENT'), isFalse);
  });

  test('a textured synthetic JPEG is smaller after platform preparation',
      () async {
    final image = source(640, 480);
    final random = Random(73);
    for (final pixel in image) {
      final n = random.nextInt(100);
      pixel.setRgba(
        (pixel.x * 3 + pixel.y + n) % 256,
        (pixel.x + pixel.y * 2 + n) % 256,
        (pixel.x * 2 + n) % 256,
        255,
      );
    }
    final input = img.encodeJpg(image, quality: 98);
    final watch = Stopwatch()..start();
    final prepared = await prepareEvidencePhoto(input);
    watch.stop();
    expect(prepared.bytes.length, lessThan(input.length));
    expect(img.decodeJpg(prepared.bytes)!.width, 640);
    debugPrint(
      'SYNTHETIC IMAGE CHECK: ${input.length} -> ${prepared.bytes.length} bytes; preparation ${watch.elapsedMilliseconds} ms. Not a device benchmark.',
    );
  });

  test('only one expensive preparation may run at a time across routes',
      () async {
    final input = img.encodeJpg(source(320, 300), quality: 95);
    final first = prepareEvidencePhoto(input);
    await expectLater(
      prepareEvidencePhoto(input),
      throwsA(isA<PhotoPreparationException>()),
    );
    await first;
  });
}
