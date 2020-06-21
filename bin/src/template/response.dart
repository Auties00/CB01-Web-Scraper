import 'dart:convert';

import 'film.dart';

class FilmResponse {
  final List<Film> films;
  FilmResponse({this.films});

  String toJson(){
    return json.encode({
      'films' : films.map((element) => element.toJson()).toList()
    });
  }
}