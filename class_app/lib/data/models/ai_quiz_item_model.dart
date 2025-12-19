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

  factory AiQuizItemModel.fromJson(Map<String, dynamic> json) {
    final optionsRaw = json['options'];
    final parsedOptions = optionsRaw is List
        ? optionsRaw.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList()
        : <String>[];

    return AiQuizItemModel(
      question: json['question']?.toString() ?? '',
      options: parsedOptions,
      answer: json['answer']?.toString() ?? '',
      explanation: json['explanation']?.toString(),
    );
  }
}
