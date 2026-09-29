class CourseModule {
  final String id;
  final int order;
  final String title;
  final String description;

  CourseModule({
    required this.id,
    required this.order,
    required this.title,
    required this.description,
  });

  factory CourseModule.fromJson(Map<String, dynamic> json) {
    return CourseModule(
      id: json['id'],
      order: json['order'],
      title: json['title'],
      description: json['description'],
    );
  }
}