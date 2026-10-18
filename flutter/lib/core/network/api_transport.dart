import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiTransport {
  ApiTransport(this.client);

  final http.Client client;

  Future<http.Response> send(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    Map<String, dynamic>? body,
    required Duration timeout,
  }) {
    final encodedBody = body == null ? null : _encodeBody(body);
    return switch (method) {
      'GET' => client.get(uri, headers: headers).timeout(timeout),
      'DELETE' => client.delete(uri, headers: headers).timeout(timeout),
      _ => client.post(uri, headers: headers, body: encodedBody).timeout(timeout),
    };
  }

  String _encodeBody(Map<String, dynamic> body) => _jsonEncode(body);

  String _jsonEncode(Object value) {
    // Kept behind this boundary so request serialization can be replaced/tested
    // independently from HTTP transport.
    return const JsonEncoder().convert(value);
  }

  void dispose() => client.close();
}
