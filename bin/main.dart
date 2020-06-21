import 'package:angel_framework/angel_framework.dart';
import 'package:angel_framework/http.dart';

import 'dart:convert';

import 'src/factory/film_manager.dart';
import 'src/template/film.dart';
import 'src/template/response.dart';

void main() async {
  var app = Angel();

  app.get('/new', (req, res) async{
    if(updating){
      throw AngelHttpException.notProcessable(
        message: 'Server is updating, try in a few minutes!',
      );
    }

    res.write(FilmResponse(films: newFilms).toJson(), encoding: Encoding.getByName('utf-8'));
    await res.close();
  });

  app.get('/recommended', (req, res) async{
    if(updating){
      throw AngelHttpException.notProcessable(
        message: 'Server is updating, try in a few minutes!',
      );
    }

    res.write(FilmResponse(films: recommendedFilms).toJson(), encoding: Encoding.getByName('utf-8'));
    await res.close();
  });

  app.get('/search', (req, res) async{
    var queryHeader = req.headers['query'];
    if(queryHeader == null){
      throw AngelHttpException.notProcessable(
        message: 'Query header is null, please correct your request!',
      );
    }

    if(updating){
      throw AngelHttpException.notProcessable(
        message: 'Server is updating, try in a few minutes!',
      );
    }

    var query = queryHeader.first;
    var films = <Film>[];

    var elements = await findFilmElementsInPage(Uri.encodeFull('https://cb01.expert/?s=$query'));
    for(var element in elements){
      var classes = await (await element.property('className')).jsonValue;
      if(classes == null || !classes.contains('post-')){
        continue;
      }

      var dataContainer = await element.$('div');
      var dataContainerChild = await dataContainer.$$('div');

      var imageAnchor = await dataContainerChild[0].$('a');
      var imageElement = await imageAnchor.$('img');
      var imageProperty = await imageElement.property('src');
      var imageUrl = await imageProperty.jsonValue;

      var titleDiv = await dataContainerChild[1].$('div');
      var titleH3 = await titleDiv.$('h3');
      var titleAnchor = await titleH3.$('a');
      var textProperty = await titleAnchor.property('innerText');
      var text = await textProperty.jsonValue;

      var titleParagraph = await titleDiv.$('p');
      var tagsSpan = await titleParagraph.$('span');
      var tagsStrong = await tagsSpan.$('strong');
      var tagsProperty = await tagsStrong.property('innerText');
      var tags = await tagsProperty.jsonValue;

      var descriptionProperty = await titleParagraph.property('innerText');
      var description = await descriptionProperty.jsonValue;
      description = descriptionProperty.toString().trim().replaceAll('...', '');

      films.add(Film(text, description, tags, imageUrl, null));
    }

    res.write(FilmResponse(films: films).toJson(), encoding: Encoding.getByName('utf-8'));
    await res.close();
  });

  app.fallback((req, res) {
    throw AngelHttpException.notFound(
      message: 'Unknown path: "${req.uri.path}"',
    );
  });

  var http = AngelHttp(app);
  var server = await http.startServer('192.168.1.30', 8080);
  await initialize();

  var url = 'http://${server.address.address}:${server.port}';
  print('Listening at $url');
}