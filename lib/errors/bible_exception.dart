class BibleException implements Exception {
  final String message;

  const BibleException(this.message);

  @override
  String toString() => message;
}

class BibleInputException extends BibleException {
  const BibleInputException(super.message);
}

class BibleNotFoundException extends BibleException {
  const BibleNotFoundException(super.message);
}

class BibleDataException extends BibleException {
  const BibleDataException(super.message);
}

class BibleConfigurationException extends BibleException {
  const BibleConfigurationException(super.message);
}
