class Pagina<T> {
  const Pagina({
    required this.content,
    required this.number,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });
  final List<T> content;
  final int number, size, totalElements, totalPages;
  bool get first => number == 0;
  bool get last => totalPages == 0 || number >= totalPages - 1;
  factory Pagina.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) => Pagina(
    content: (json['content'] as List)
        .map((e) => parse(Map<String, dynamic>.from(e)))
        .toList(),
    number: (json['number'] as num).toInt(),
    size: (json['size'] as num).toInt(),
    totalElements: (json['totalElements'] as num).toInt(),
    totalPages: (json['totalPages'] as num).toInt(),
  );
}
