// ignore_for_file: invalid_use_of_protected_member

import 'dart:io';
import 'dart:typed_data';

import 'package:alchemist/src/alchemist_file_comparator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

class MockLocalFileComparator extends Mock implements LocalFileComparator {}

// Load a real PNG file for testing
Future<Uint8List> loadTestPng() async {
  final file = File('test/src/test_image.png');
  return file.readAsBytes();
}

void main() {
  group('AlchemistFileComparator', () {
    late AlchemistFileComparator comparator;
    late Directory tempDir;
    late Uri goldenUri;
    late Uint8List testImageBytes;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('alchemist_test_');
      comparator = AlchemistFileComparator(basedir: tempDir.uri, tolerance: 0);
      goldenUri = Uri.parse('test_golden.png');
      testImageBytes = await loadTestPng();
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('can be constructed', () {
      expect(
        () => AlchemistFileComparator(basedir: Uri.parse('./'), tolerance: 0),
        returnsNormally,
      );
    });

    test('.fromLocalFileComparator returns correctly', () {
      final uri = Uri.parse('./');
      final style = path.Style.platform;

      final lfc = MockLocalFileComparator();
      when(() => lfc.basedir).thenReturn(uri);

      expect(
        AlchemistFileComparator.fromLocalFileComparator(lfc, tolerance: 0),
        isA<AlchemistFileComparator>()
            .having((a) => a.basedir, 'basedir', equals(same(uri)))
            .having((a) => a.tolerance, 'tolerance', equals(0))
            .having((a) => a.path.style, 'path.style', equals(same(style))),
      );
    });

    group('compare', () {
      test(
        'returns true when images match exactly with zero tolerance',
        () async {
          final goldenFile = File(path.join(tempDir.path, 'test_golden.png'));
          await goldenFile.writeAsBytes(testImageBytes);

          final result = await comparator.compare(testImageBytes, goldenUri);

          expect(result, isTrue);
        },
      );

      test('throws TestFailure when golden file does not exist', () async {
        expect(
          () => comparator.compare(testImageBytes, goldenUri),
          throwsA(
            isA<TestFailure>().having(
              (failure) => failure.message,
              'message',
              contains('Could not be compared against non-existent file'),
            ),
          ),
        );
      });
    });

    group('update', () {
      test('creates golden file with provided image bytes', () async {
        await comparator.update(goldenUri, testImageBytes);

        final goldenFile = File(path.join(tempDir.path, 'test_golden.png'));
        expect(goldenFile.existsSync(), isTrue);
        expect(await goldenFile.readAsBytes(), equals(testImageBytes));
      });

      test('creates parent directories if they do not exist', () async {
        final nestedGoldenUri = Uri.parse('nested/dir/test_golden.png');

        await comparator.update(nestedGoldenUri, testImageBytes);

        final goldenFile = File(
          path.join(tempDir.path, 'nested', 'dir', 'test_golden.png'),
        );
        expect(goldenFile.existsSync(), isTrue);
        expect(await goldenFile.readAsBytes(), equals(testImageBytes));
      });

      test('overwrites existing golden file', () async {
        final imageBytes2 = Uint8List.fromList([5, 6, 7, 8, 9, 10, 11, 12]);

        await comparator.update(goldenUri, testImageBytes);
        await comparator.update(goldenUri, imageBytes2);

        final goldenFile = File(path.join(tempDir.path, 'test_golden.png'));
        expect(await goldenFile.readAsBytes(), equals(imageBytes2));
      });

      test('handles empty image bytes', () async {
        final emptyImageBytes = Uint8List(0);

        await comparator.update(goldenUri, emptyImageBytes);

        final goldenFile = File(path.join(tempDir.path, 'test_golden.png'));
        expect(goldenFile.existsSync(), isTrue);
        expect(await goldenFile.readAsBytes(), equals(emptyImageBytes));
      });
    });

    group('getGoldenBytes', () {
      test('returns golden file bytes when file exists', () async {
        final goldenFile = File(path.join(tempDir.path, 'test_golden.png'));
        await goldenFile.writeAsBytes(testImageBytes);

        final result = await comparator.getGoldenBytes(goldenUri);

        expect(result, equals(testImageBytes));
      });

      test('throws TestFailure when golden file does not exist', () async {
        expect(
          () => comparator.getGoldenBytes(goldenUri),
          throwsA(
            isA<TestFailure>().having(
              (failure) => failure.message,
              'message',
              contains('Could not be compared against non-existent file'),
            ),
          ),
        );
      });

      test('handles nested golden file paths', () async {
        final nestedGoldenUri = Uri.parse('nested/dir/test_golden.png');
        final goldenFile = File(
          path.join(tempDir.path, 'nested', 'dir', 'test_golden.png'),
        );
        await goldenFile.parent.create(recursive: true);
        await goldenFile.writeAsBytes(testImageBytes);

        final result = await comparator.getGoldenBytes(nestedGoldenUri);

        expect(result, equals(testImageBytes));
      });

      test(
        'throws TestFailure for nested path when file does not exist',
        () async {
          final nestedGoldenUri = Uri.parse('nested/dir/test_golden.png');

          expect(
            () => comparator.getGoldenBytes(nestedGoldenUri),
            throwsA(
              isA<TestFailure>().having(
                (failure) => failure.message,
                'message',
                contains('Could not be compared against non-existent file'),
              ),
            ),
          );
        },
      );
    });
  });
}
