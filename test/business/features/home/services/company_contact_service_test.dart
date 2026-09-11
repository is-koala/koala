import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/models/company_contact.dart';
import 'package:koala/business/features/home/models/company_contact_invitation.dart';
import 'package:koala/business/features/home/services/company_contact_service.dart';
import 'package:koala/product/network/api_exception.dart';

import '../../../../support/fake_api.dart';

const _user = {
  'id': 'user-2',
  'firstName': 'Ayşe',
  'lastName': 'Yılmaz',
  'username': 'ayse',
  'profilePictureUrl': 'https://cdn.example/ayse.jpg',
};

const _inviter = {
  'id': 'user-1',
  'firstName': 'Ali',
  'lastName': 'Veli',
  'username': 'ali',
};

const _contact = {'id': 'contact-1', 'user': _user, 'role': 'STAFF'};

const _company = {'id': 'comp_1', 'name': 'Kahve Durağı'};

const _invitation = {
  'id': 'invite-1',
  'company': _company,
  'invitedBy': _inviter,
  'invitedUser': _user,
  'role': 'ADMIN',
  'status': 'PENDING',
  'invitedAt': '2026-09-11T08:00:00Z',
  'answeredAt': null,
};

FakeApiResponse _ok(Object data, {int statusCode = 200}) {
  return FakeApiResponse(
    statusCode: statusCode,
    body: {'success': true, 'data': data},
  );
}

FakeApiResponse _error({
  required int statusCode,
  required String errorCode,
  String message = 'hata',
  String errorCategory = 'DATA_CONFLICT',
}) {
  return FakeApiResponse(
    statusCode: statusCode,
    body: {
      'success': false,
      'message': message,
      'errorCode': errorCode,
      'errorCategory': errorCategory,
    },
  );
}

void main() {
  group('CompanyContactService.fetchContacts', () {
    test('yetkililer listesi modele çevriliyor', () async {
      final api = FakeApi(handler: (_) => _ok([_contact]));

      final contacts = await CompanyContactService.withClient(
        api.client,
      ).fetchContacts('comp_1');

      expect(api.requests.single.method, 'GET');
      expect(api.requests.single.path, '/companies/comp_1/contacts');
      expect(contacts, hasLength(1));
      expect(contacts.single.user.firstName, 'Ayşe');
      expect(contacts.single.role, CompanyContactRole.staff);
      expect(contacts.single.role.displayName, 'Çalışan');
    });
  });

  group('CompanyContactService.inviteContact', () {
    test('e-posta ve rol POST gövdesine yazılıyor', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 201, body: {'success': true}),
      );

      await CompanyContactService.withClient(api.client).inviteContact(
        'comp_1',
        email: 'ayse@example.com',
        role: CompanyContactRole.admin,
      );

      final request = api.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/companies/comp_1/contact-invitations');
      expect(request.data, {'email': 'ayse@example.com', 'role': 'ADMIN'});
    });

    test('kayıtlı olmayan e-posta kullanıcı bulunamadı diyor', () async {
      final api = FakeApi(
        handler: (_) => _error(
          statusCode: 404,
          errorCode: 'USER_NOT_FOUND_BY_EMAIL',
          errorCategory: 'RESOURCE_NOT_FOUND',
        ),
      );

      final error = await _catch(
        () => CompanyContactService.withClient(api.client).inviteContact(
          'comp_1',
          email: 'yok@example.com',
          role: CompanyContactRole.staff,
        ),
      );

      expect(CompanyContactService.messageFor(error), 'Kullanıcı bulunamadı');
    });

    test('zaten yetkili kullanıcı ayrı mesaj alıyor', () async {
      final api = FakeApi(
        handler: (_) =>
            _error(statusCode: 409, errorCode: 'USER_ALREADY_A_CONTACT'),
      );

      final error = await _catch(
        () => CompanyContactService.withClient(api.client).inviteContact(
          'comp_1',
          email: 'ayse@example.com',
          role: CompanyContactRole.staff,
        ),
      );

      expect(
        CompanyContactService.messageFor(error),
        'Bu kullanıcı zaten yetkili',
      );
    });

    test('kimliği doğrulanmamış kullanıcı ayrı mesaj alıyor', () async {
      final api = FakeApi(
        handler: (_) => _error(
          statusCode: 400,
          errorCode: 'USER_MUST_VERIFY_IDENTITY',
          errorCategory: 'VALIDATION_FAILED',
        ),
      );

      final error = await _catch(
        () => CompanyContactService.withClient(api.client).inviteContact(
          'comp_1',
          email: 'ayse@example.com',
          role: CompanyContactRole.staff,
        ),
      );

      expect(
        CompanyContactService.messageFor(error),
        'Kullanıcı önce kimliğini doğrulamalı',
      );
    });

    test('bekleyen davet ayrı mesaj alıyor', () async {
      final api = FakeApi(
        handler: (_) => _error(
          statusCode: 409,
          errorCode: 'COMPANY_CONTACT_INVITATION_ALREADY_PENDING',
        ),
      );

      final error = await _catch(
        () => CompanyContactService.withClient(api.client).inviteContact(
          'comp_1',
          email: 'ayse@example.com',
          role: CompanyContactRole.staff,
        ),
      );

      expect(
        CompanyContactService.messageFor(error),
        'Bu kişiye zaten bekleyen bir davet var',
      );
    });
  });

  group('CompanyContactService.removeContact', () {
    test('DELETE yolu kullanıcı kimliğini taşır', () async {
      final api = FakeApi(
        handler: (_) =>
            const FakeApiResponse(statusCode: 200, body: {'success': true}),
      );

      await CompanyContactService.withClient(
        api.client,
      ).removeContact('comp_1', 'user-2');

      expect(api.requests.single.method, 'DELETE');
      expect(api.requests.single.path, '/companies/comp_1/contacts/user-2');
    });

    test('son yönetici çıkarılamaz', () async {
      final api = FakeApi(
        handler: (_) => _error(
          statusCode: 409,
          errorCode: 'COMPANY_LAST_ADMIN_CANNOT_BE_REMOVED',
        ),
      );

      final error = await _catch(
        () => CompanyContactService.withClient(
          api.client,
        ).removeContact('comp_1', 'user-1'),
      );

      expect(
        CompanyContactService.messageFor(error),
        'Son yönetici çıkarılamaz',
      );
    });
  });

  group('CompanyContactService davet okuma ve cevap', () {
    test('davet detayı GET ile çekiliyor', () async {
      final api = FakeApi(handler: (_) => _ok(_invitation));

      final invitation = await CompanyContactService.withClient(
        api.client,
      ).fetchInvitation('invite-1');

      expect(api.requests.single.method, 'GET');
      expect(api.requests.single.path, '/contact-invitations/invite-1');
      expect(invitation.companyName, 'Kahve Durağı');
      expect(invitation.invitedBy.fullName, 'Ali Veli');
      expect(invitation.role, CompanyContactRole.admin);
      expect(invitation.status, CompanyContactInvitationStatus.pending);
      expect(invitation.isPending, isTrue);
    });

    test('kabul gövdesi accepted true gönderiyor', () async {
      final api = FakeApi(
        handler: (_) => _ok({..._invitation, 'status': 'ACCEPTED'}),
      );

      final invitation = await CompanyContactService.withClient(
        api.client,
      ).answerInvitation('invite-1', accepted: true);

      final request = api.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/contact-invitations/invite-1');
      expect(request.data, {'accepted': true});
      expect(invitation.status, CompanyContactInvitationStatus.accepted);
    });

    test('zaten cevaplanmış davet ayrı mesaj alıyor', () async {
      final api = FakeApi(
        handler: (_) =>
            _error(statusCode: 409, errorCode: 'INVITATION_ALREADY_ANSWERED'),
      );

      final error = await _catch(
        () => CompanyContactService.withClient(
          api.client,
        ).answerInvitation('invite-1', accepted: false),
      );

      expect(
        CompanyContactService.messageFor(error),
        'Bu davet zaten cevaplanmış',
      );
    });

    test('bulunamayan davet varlığı sızdırmıyor', () async {
      final api = FakeApi(
        handler: (_) => _error(
          statusCode: 404,
          errorCode: 'COMPANY_CONTACT_INVITATION_NOT_FOUND',
          errorCategory: 'RESOURCE_NOT_FOUND',
        ),
      );

      final error = await _catch(
        () => CompanyContactService.withClient(
          api.client,
        ).fetchInvitation('invite-missing'),
      );

      expect(
        CompanyContactService.messageFor(error),
        'Davet bulunamadı ya da size ait değil.',
      );
    });
  });

  group('CompanyContactRole', () {
    test('yönetici görünen adı Türkçe', () {
      expect(CompanyContactRole.admin.displayName, 'Yönetici');
      expect(CompanyContactRole.fromCode('ADMIN'), CompanyContactRole.admin);
      expect(CompanyContactRole.fromCode('OWNER'), isNull);
    });
  });
}

Future<ApiException> _catch(Future<void> Function() action) async {
  try {
    await action();
    fail('ApiException bekleniyordu');
  } on ApiException catch (error) {
    return error;
  }
}
