class Film{
  final String name;
  final String description;
  final String tags;
  final String thumbnailUrl;
  final String streamUrl;
  final String url;

  Film(this.name, this.description, this.tags, this.thumbnailUrl, this.streamUrl, this.url);

  @override
  String toString() {
    return 'Film: {$name, $description, $tags, $thumbnailUrl, $streamUrl}';
  }

  Map<String, dynamic> toJson(){
    return {
      'name' : name,
      'description' : description,
      'tags' : tags,
      'thumbnailUrl' : thumbnailUrl,
      'streamUrl' : streamUrl,
      'url' : url
    };
  }
}