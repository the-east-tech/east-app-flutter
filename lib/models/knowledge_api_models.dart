import 'api_models.dart';
import 'app_models.dart';

KnowledgeItem knowledgeItemFromJson(Map<String, dynamic> json) {
  final id = json['id'] as String;
  return KnowledgeItem(
    id: id,
    youtubeUrl: json['youtubeUrl'] as String,
    youtubeVideoId: json['youtubeVideoId'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    type: 'SOP',
    tagId: json['tagId'] as String,
    tagName: json['tagName'] as String? ?? '',
    mediaType: 'video',
    expectedOutcome: json['expectedOutcome'] as String,
    language: KnowledgeVideoLanguage.fromApi(json['language'] as String?),
    linkGroupId: json['linkGroupId'] as String? ?? id,
    createdBy: json['createdBy'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal(),
  );
}

Map<String, Object?> knowledgeItemToJson(
  KnowledgeItem item, {
  bool includeLinkedSop = false,
}) {
  return {
    'youtubeUrl': item.youtubeUrl,
    'tagId': item.tagId,
    'title': item.title,
    'expectedOutcome': item.expectedOutcome,
    'description': item.description,
    'language': item.language.apiValue,
    if (includeLinkedSop && item.linkedSopId?.trim().isNotEmpty == true)
      'linkedSopId': item.linkedSopId!.trim(),
  };
}

EastAppPage<KnowledgeItem> knowledgeItemPageFromJson(
  Map<String, dynamic> json,
) {
  return EastAppPage.fromJson(json, knowledgeItemFromJson);
}
