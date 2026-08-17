import 'api_models.dart';
import 'app_models.dart';

KnowledgeItem knowledgeItemFromJson(Map<String, dynamic> json) {
  return KnowledgeItem(
    id: json['id'] as String,
    youtubeUrl: json['youtubeUrl'] as String,
    youtubeVideoId: json['youtubeVideoId'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    type: 'SOP',
    tagId: json['tagId'] as String,
    tagName: json['tagName'] as String? ?? '',
    mediaType: 'video',
    expectedOutcome: json['expectedOutcome'] as String,
    createdBy: json['createdBy'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal(),
  );
}

Map<String, Object?> knowledgeItemToJson(KnowledgeItem item) {
  return {
    'youtubeUrl': item.youtubeUrl,
    'tagId': item.tagId,
    'title': item.title,
    'expectedOutcome': item.expectedOutcome,
    'description': item.description,
  };
}

EastAppPage<KnowledgeItem> knowledgeItemPageFromJson(
  Map<String, dynamic> json,
) {
  return EastAppPage.fromJson(json, knowledgeItemFromJson);
}
