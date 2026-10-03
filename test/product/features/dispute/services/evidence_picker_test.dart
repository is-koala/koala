import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/features/dispute/models/evidence_file.dart';
import 'package:koala/product/features/dispute/services/evidence_picker.dart';

import '../../../../support/dispute_evidence_fixtures.dart';

/// Seçilmiş bir dosya: yalnız ad ve yol okunuyor. `PlatformFile` soyut ve
/// `base`; kullanılmayan üyeleri `noSuchMethod` karşılıyor.
base class _FakePlatformFile extends PlatformFile {
  _FakePlatformFile(this._name, [this._path]);

  final String _name;
  final String? _path;

  @override
  String get name => _name;

  /// Yolu olmayan (diskte olmayan) bir dosya `blob:` adresiyle temsil ediliyor.
  @override
  Uri get uri => _path == null ? Uri.parse('blob:yok') : Uri.file(_path);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `file_picker`'ın platform kapısının yerine geçer. `file_picker` bunu
/// yeniden dışa aktarıyor; ayrıca paket bağımlılığı gerekmiyor.
class _FakeFilePickerPlatform extends FilePickerPlatform {
  _FakeFilePickerPlatform(this.result);

  /// Seçici kapanınca dönecek dosya; `null` kullanıcının vazgeçtiği anlamına
  /// geliyor.
  final PlatformFile? result;

  FileType? requestedType;
  List<String>? requestedExtensions;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool lockParentWindow = false,
    bool cancelUploadOnWindowBlur = true,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    requestedType = type;
    requestedExtensions = allowedExtensions;
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EvidencePicker.candidateFor', () {
    test('boyutu ve yalnızca ilk on iki baytı okur', () {
      final path = writeEvidenceFile('a.pdf', [
        ...pdfBytes,
        ...List.filled(500, 7),
      ]);

      final candidate = EvidencePicker.candidateFor(
        path,
        displayName: 'tutanak',
      );

      expect(candidate.path, path);
      expect(candidate.bytes, pdfBytes.length + 500);
      expect(candidate.head, hasLength(EvidenceFormat.signatureLength));
      expect(EvidenceFormat.detect(candidate.head), EvidenceFormat.pdf);
      expect(candidate.displayName, 'tutanak');
    });

    test('boş dosya sıfır bayt ve boş başlık', () {
      final path = writeEvidenceFile('bos.pdf', const []);

      final candidate = EvidencePicker.candidateFor(path);

      expect(candidate.bytes, 0);
      expect(candidate.head, isEmpty);
      expect(candidate.displayName, isNull);
      expect(
        DisputeEvidencePolicy.accept(
          candidate,
          now: DateTime(2026, 10, 3),
        ).rejection,
        EvidenceRejection.empty,
      );
    });
  });

  group('EvidencePicker.pick (fotoğraf)', () {
    const channel = MethodChannel('plugins.flutter.io/image_picker');
    late List<MethodCall> calls;
    late String? pickedPath;

    setUp(() {
      calls = [];
      pickedPath = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return pickedPath;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    // `image_picker`'a her seferinde ölçek ve kalite veriliyor: dosya sunucu
    // sınırının altında kalıyor ve iPhone'un HEIC'i JPEG'e çevriliyor.
    test('kamera: arka kamera, ölçek ve kalite ile; ad verilmez', () async {
      pickedPath = writeEvidenceFile('gecici.jpg', jpegSignatureBytes);

      final candidate = await const EvidencePicker().pick(
        EvidenceSource.camera,
      );

      final args = calls.single.arguments as Map<Object?, Object?>;
      expect(calls.single.method, 'pickImage');
      expect(args['source'], 0, reason: 'ImageSource.camera');
      expect(args['maxWidth'], DisputeEvidencePolicy.maxDimension);
      expect(args['maxHeight'], DisputeEvidencePolicy.maxDimension);
      expect(args['imageQuality'], DisputeEvidencePolicy.quality);
      expect(args['cameraDevice'], 0, reason: 'CameraDevice.rear');
      expect(candidate!.path, pickedPath);
      expect(candidate.bytes, jpegSignatureBytes.length);
      expect(EvidenceFormat.detect(candidate.head), EvidenceFormat.jpeg);
      // Seçicinin geçici adı taşınmıyor; ad yükleme anında üretilecek.
      expect(candidate.displayName, isNull);
    });

    test('galeri: aynı ölçek ve kalite, kaynak galeri', () async {
      pickedPath = writeEvidenceFile('galeri.png', onePixelPng);

      final candidate = await const EvidencePicker().pick(
        EvidenceSource.gallery,
      );

      final args = calls.single.arguments as Map<Object?, Object?>;
      expect(args['source'], 1, reason: 'ImageSource.gallery');
      expect(args['maxWidth'], DisputeEvidencePolicy.maxDimension);
      expect(args['imageQuality'], DisputeEvidencePolicy.quality);
      expect(EvidenceFormat.detect(candidate!.head), EvidenceFormat.png);
    });

    test('vazgeçilirse null', () async {
      pickedPath = null;

      expect(await const EvidencePicker().pick(EvidenceSource.gallery), isNull);
    });

    test('izin reddi PlatformException olarak çıkar', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'camera_access_denied');
          });

      await expectLater(
        const EvidencePicker().pick(EvidenceSource.camera),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'camera_access_denied',
          ),
        ),
      );
    });
  });

  group('EvidencePicker.pick (belge)', () {
    final original = FilePickerPlatform.instance;
    tearDown(() => FilePickerPlatform.instance = original);

    test('yalnız PDF istenir, dosyanın kendi adı korunur', () async {
      final path = writeEvidenceFile('tutanak.pdf', pdfBytes);
      final platform = _FakeFilePickerPlatform(
        _FakePlatformFile('Tutanak 1.pdf', path),
      );
      FilePickerPlatform.instance = platform;

      final candidate = await const EvidencePicker().pick(
        EvidenceSource.document,
      );

      expect(platform.requestedType, FileType.custom);
      expect(platform.requestedExtensions, ['pdf']);
      expect(candidate!.path, path);
      expect(candidate.displayName, 'Tutanak 1.pdf');
      expect(EvidenceFormat.detect(candidate.head), EvidenceFormat.pdf);
    });

    test('vazgeçilirse ya da yol yoksa null', () async {
      FilePickerPlatform.instance = _FakeFilePickerPlatform(null);
      expect(
        await const EvidencePicker().pick(EvidenceSource.document),
        isNull,
      );

      FilePickerPlatform.instance = _FakeFilePickerPlatform(
        _FakePlatformFile('x.pdf'),
      );
      expect(
        await const EvidencePicker().pick(EvidenceSource.document),
        isNull,
      );
    });
  });

  test('üç kaynak: kamera, galeri, belge', () {
    expect(EvidenceSource.values, [
      EvidenceSource.camera,
      EvidenceSource.gallery,
      EvidenceSource.document,
    ]);
  });

  test('seçici geçici dosyayı okuyabilir bırakır', () {
    final path = writeEvidenceFile('a.pdf', pdfBytes);

    EvidencePicker.candidateFor(path);

    expect(File(path).existsSync(), isTrue);
  });
}
