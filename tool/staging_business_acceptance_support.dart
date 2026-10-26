// Test tooling only: no administrator credentials, state overrides or UI paths.
import 'dart:typed_data';
import 'package:image/image.dart' as image;

const businessStagingRef = 'gqtetdavmrautoojaqrk';
const businessFixtureKind = 'isolated-booking-run-v1';
final businessUuid =
    RegExp(r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$');

void requireBusinessTarget(Map config, Map fixture, String confirmation) {
  if (confirmation != businessStagingRef ||
      config['APP_ENV'] != 'staging' ||
      config['SUPABASE_PROJECT_REF'] != businessStagingRef ||
      config['SUPABASE_URL'] != 'https://$businessStagingRef.supabase.co' ||
      config['ALLOW_PRODUCTION_BACKEND'] != false ||
      fixture['project_ref'] != businessStagingRef ||
      fixture['environment'] != 'staging' ||
      fixture['fixture'] != businessFixtureKind ||
      !businessUuid.hasMatch('${fixture['run_id']}')) {
    throw StateError('Explicit isolated Staging confirmation required.');
  }
  final accounts = (fixture['accounts'] as List).cast<Map>();
  if (accounts.length != 2) {
    throw StateError('Two fixture identities required.');
  }
  for (final role in ['owner', 'provider']) {
    final account = accounts.singleWhere((a) => a['role'] == role);
    if (account['email'] != '$role.${fixture['run_id']}@rental-test.invalid' ||
        !businessUuid.hasMatch('${account['user_id']}') ||
        account['password'] is! String ||
        (account['password'] as String).length < 32) {
      throw StateError('Only exact dedicated synthetic identities permitted.');
    }
  }
  if (accounts.first['user_id'] == accounts.last['user_id']) {
    throw StateError('Distinct identities required.');
  }
}

void requireBusinessState(Map state, Map fixture) {
  if (state['version'] != 1 ||
      state['project_ref'] != businessStagingRef ||
      state['run_id'] != fixture['run_id']) {
    throw StateError('Acceptance checkpoint belongs to another run.');
  }
  for (final name in [
    'request_id',
    'owner_message_id',
    'provider_message_id',
    'before_upload_id',
    'after_upload_id',
    'property_id',
    'service_type_id',
  ]) {
    if (!businessUuid.hasMatch('${state[name]}')) {
      throw StateError('Invalid acceptance checkpoint identifier.');
    }
  }
  final start = DateTime.parse(state['start'] as String);
  final end = DateTime.parse(state['end'] as String);
  if (!start.isUtc ||
      !end.isUtc ||
      end.difference(start) != const Duration(hours: 2) ||
      state['amount'] != 80 ||
      state['basis'] != 'hourly') {
    throw StateError('Unexpected checkpoint quote/window.');
  }
}

// Clearly synthetic, small, reproducible pixel fixtures. These prove byte
// validation/storage wiring, never that cleaning occurred or quality was judged.
Uint8List businessTestPhoto(bool before) {
  final picture = image.Image(width: 160, height: 80, numChannels: 4);
  image.fill(
    picture,
    color: before
        ? image.ColorRgba8(225, 205, 170, 255)
        : image.ColorRgba8(175, 220, 205, 255),
  );
  image.drawString(
    picture,
    '[TEST]',
    font: image.arial14,
    x: 8,
    y: 8,
    color: image.ColorRgba8(25, 35, 70, 255),
  );
  image.drawString(
    picture,
    before ? 'BEFORE' : 'AFTER',
    font: image.arial14,
    x: 8,
    y: 35,
    color: image.ColorRgba8(25, 35, 70, 255),
  );
  return Uint8List.fromList(image.encodePng(picture));
}
