class ApiConfig {
  String apiKey;
  String modelName;
  String baseUrl;
  
  ApiConfig({
    required this.apiKey,
    required this.modelName,
    required this.baseUrl,
  });

  factory ApiConfig.fromJson(Map<String, dynamic> json) {
    return ApiConfig(
      apiKey: json['apiKey'] ?? '',
      modelName: json['modelName'] ?? '',
      baseUrl: json['baseUrl'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'apiKey': apiKey,
      'modelName': modelName,
      'baseUrl': baseUrl,
    };
  }
}
