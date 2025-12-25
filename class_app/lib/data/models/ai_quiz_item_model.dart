class AiQuizItemModel {
  const AiQuizItemModel({
    required this.question,
    required this.options,
    required this.answer,
    this.explanation,
  });

  final String question;
  final List<String> options;
  final String answer;
  final String? explanation;

  static final RegExp _optionLabelPattern =
      RegExp(r'^[A-Ha-h]\s*[\).:\-]\s*');

  factory AiQuizItemModel.fromJson(Map<String, dynamic> json) {
    final optionsRaw = json['options'];
    final parsedOptions = optionsRaw is List
        ? optionsRaw
            .map((e) => e?.toString() ?? '')
            .map(_normalizeOption)
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];

    return AiQuizItemModel(
      question: json['question']?.toString() ?? '',
      options: parsedOptions,
      answer: json['answer']?.toString() ?? '',
      explanation: json['explanation']?.toString(),
    );
  }

  static String _normalizeOption(String option) {
    var normalized = option.trim();
    while (true) {
      final match = _optionLabelPattern.firstMatch(normalized);
      if (match == null) {
        break;
      }
      normalized = normalized.substring(match.end).trimLeft();
    }
    return normalized;
  }
}
