import 'package:flutter_dotenv/flutter_dotenv.dart';

const _loopbackHosts = {'127.0.0.1', 'localhost', '::1'};
const _mediaFieldNames = {'avatar', 'interlocutor_avatar'};

String resolveApiBaseUrl() {
  const baseUrlFromDefine =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');
  const appEnvFromDefine = String.fromEnvironment('APP_ENV', defaultValue: '');

  String normalize(String value) => value.trim();

  final overriddenByDefine = normalize(baseUrlFromDefine);
  if (overriddenByDefine.isNotEmpty) {
    return overriddenByDefine;
  }

  final explicitFromDotEnv = normalize(dotenv.env['API_BASE_URL'] ?? '');
  if (explicitFromDotEnv.isNotEmpty) {
    return explicitFromDotEnv;
  }

  final selectedEnv = normalize(
    appEnvFromDefine.isNotEmpty
        ? appEnvFromDefine
        : (dotenv.env['APP_ENV'] ?? ''),
  ).toLowerCase();

  if (selectedEnv == 'local' ||
      selectedEnv == 'dev' ||
      selectedEnv == 'development') {
    final localFromDotEnv = normalize(dotenv.env['API_BASE_URL_LOCAL'] ?? '');
    if (localFromDotEnv.isNotEmpty) {
      return localFromDotEnv;
    }
    return 'http://127.0.0.1:8000';
  }

  final productionFromDotEnv = normalize(dotenv.env['API_BASE_URL_PROD'] ?? '');
  if (productionFromDotEnv.isNotEmpty) {
    return productionFromDotEnv;
  }

  return 'https://api.goklinik.com';
}

bool _isLoopbackHost(String host) =>
    _loopbackHosts.contains(host.trim().toLowerCase());

String resolveApiMediaUrl(String rawUrl) {
  final value = rawUrl.trim();
  if (value.isEmpty) {
    return '';
  }

  final baseUri = Uri.tryParse(resolveApiBaseUrl());
  final hasValidBase = baseUri != null && baseUri.host.isNotEmpty;

  if (value.startsWith('//')) {
    final scheme = hasValidBase
        ? (baseUri.scheme.isEmpty ? 'https' : baseUri.scheme)
        : 'https';
    return '$scheme:$value';
  }

  final parsed = Uri.tryParse(value);
  if (parsed != null && parsed.hasScheme) {
    if (hasValidBase &&
        _isLoopbackHost(parsed.host) &&
        !_isLoopbackHost(baseUri.host)) {
      return parsed
          .replace(
            scheme: baseUri.scheme.isEmpty ? 'https' : baseUri.scheme,
            host: baseUri.host,
            port: baseUri.hasPort ? baseUri.port : null,
          )
          .toString();
    }
    return value;
  }

  if (!hasValidBase) {
    return value;
  }

  final origin = Uri(
    scheme: baseUri.scheme.isEmpty ? 'https' : baseUri.scheme,
    host: baseUri.host,
    port: baseUri.hasPort ? baseUri.port : null,
  );
  final normalizedPath = value.startsWith('/') ? value : '/$value';
  return origin.resolve(normalizedPath).toString();
}

String? resolveNullableApiMediaUrl(String? rawUrl) {
  if (rawUrl == null) return null;
  final resolved = resolveApiMediaUrl(rawUrl);
  return resolved.isEmpty ? null : resolved;
}

bool _isMediaKey(String key) =>
    key.toLowerCase().endsWith('_url') || _mediaFieldNames.contains(key);

dynamic normalizeApiMediaPayload(dynamic input) {
  if (input is List) {
    return input.map(normalizeApiMediaPayload).toList();
  }

  if (input is Map) {
    final messageType = (input['message_type'] ?? '').toString().toLowerCase();
    final normalized = <dynamic, dynamic>{};

    input.forEach((key, value) {
      final keyText = key is String ? key : key.toString();
      if (value is String && _isMediaKey(keyText)) {
        normalized[key] = resolveApiMediaUrl(value);
        return;
      }
      if (value is String && keyText == 'content' && messageType == 'image') {
        normalized[key] = resolveApiMediaUrl(value);
        return;
      }
      normalized[key] = normalizeApiMediaPayload(value);
    });

    return normalized;
  }

  return input;
}
