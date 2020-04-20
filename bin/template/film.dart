class Film{
  final String _name;
  final String _description;
  final String _tags;
  final String _thumbnailUrl;
  final String _streamUrl;

  Film(this._name, this._description, this._tags, this._thumbnailUrl, this._streamUrl);

  @override
  String toString() {
    return 'Film: {$_name, $_description, $_tags, $_thumbnailUrl, $_streamUrl}';
  }

  Map<String, dynamic> toJson(){
    return {
      'name' : _name,
      'description' : _description,
      'tags' : _tags,
      'thumbnailUrl' : _thumbnailUrl,
      'streamUrl' : _streamUrl
    };
  }
}

class FilmContainer {
  final List<Film> films;
  FilmContainer(this.films);

  Map<String, dynamic> toJson(){
    return {
      'films' : films.map((element) => element.toJson()).toList()
    };
  }
}