// Send a text message to another user "dst"

/*
String sendDirectTextMessage(
    String dstName, String contents, RSAPublicKey recipientPublicKey) {
  String uuid = UUID.v4();

  Uint8List encryptedMessage =
      rsaEncrypt(recipientPublicKey, utf8.encode(contents));

  Uint8List payload = new DMMessage(uuid, clientName, dstName, clientNickname,
          "DMText", base64.encode(encryptedMessage))
      .encode();
  onPayLoadReceive(clientName, payload);

  return uuid;
}
*/
