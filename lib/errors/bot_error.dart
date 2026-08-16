abstract class BotException implements Exception {
  final String userMessage;

  const BotException(this.userMessage);

  @override
  String toString() => userMessage;
}

class UserInputException extends BotException {
  const UserInputException(super.userMessage);
}

class NotFoundException extends BotException {
  const NotFoundException(super.userMessage);
}

class DataException extends BotException {
  const DataException(super.userMessage);
}

class ConfigurationException extends BotException {
  const ConfigurationException(super.userMessage);
}
