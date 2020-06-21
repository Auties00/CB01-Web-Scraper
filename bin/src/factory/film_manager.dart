import 'dart:async';

import 'package:pedantic/pedantic.dart';
import 'package:puppeteer/puppeteer.dart';

import '../template/film.dart';

final RegExp linkExpression = RegExp(r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=,]*)');
List<Film> recommendedFilms;
List<Film> newFilms;
var updating = false;
var lastTime;
Browser browser;

Future initialize() async {
  browser ??= await puppeteer.launch(
      headless: false,
      executablePath: 'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe'
  );

  updating = true;

  var myPage = await browser.newPage();
  await myPage.goto('https://cb01.trade/', wait: Until.domContentLoaded);

  var newFilmsTemp = await myPage.$$('li.wa_chpcs_foo_content');
  var newFilmsList = <Film>[];
  for(var filmElement in newFilmsTemp){
    var linkContainer = await filmElement.$('div');
    var linkPropertyContainer = await linkContainer.$('a');
    var linkProperty = await linkPropertyContainer.property('href');
    var link = await linkProperty.jsonValue;

    var page = await browser.newPage();
    await page.goto(link, wait: Until.domContentLoaded);

    await _extractFile(page, newFilmsList);

    await page.close();
  }


  var recommendedFilmsList = <Film>[];
  var elements = await findFilmElementsInPage('https://cb01.trade/');
  for(var recommendedFilm in elements){
    var classes = await (await recommendedFilm.property('className')).jsonValue;
    if(classes == null || !classes.contains('post-')){
      continue;
    }

    var linkContainerDiv = await recommendedFilm.$('div');
    var linkContainerAnchor = await linkContainerDiv.$('a');
    var linkContainerAnchorDiv = await linkContainerAnchor.$('div.card-image');

    var linkContainerAnchorDivAnchor;
    if(linkContainerAnchorDiv == null){
      linkContainerAnchor = await linkContainerDiv.$('div');
      linkContainerAnchorDivAnchor = await linkContainerAnchor.$('a');
    }else {
      linkContainerAnchorDivAnchor = await linkContainerAnchorDiv.$('a');
    }

    var linkProperty = await linkContainerAnchorDivAnchor.property('href');
    var link = await linkProperty.jsonValue;

    var page = await browser.newPage();
    await page.goto(link, wait: Until.domContentLoaded);

    await _extractFile(page, recommendedFilmsList);

    await page.close();
  }

  newFilms = newFilmsList;
  recommendedFilms = recommendedFilmsList;
  updating = false;
  lastTime = DateTime.now();
}

Future<List<ElementHandle>> findFilmElementsInPage(String url) async{
  var page = await browser.newPage();
  await page.goto(url, wait: Until.domContentLoaded);
  var recommendedFilmsDiv = await page.$('div.sequex-one-columns');
  var recommendedFilmsContainer = await recommendedFilmsDiv.$('div');
  return await recommendedFilmsContainer.$$('div');
}

void _extractFile(Page page, List newFilms) async{
  var thumbnailContainer = await page.$('div.sequex-featured-img');
  var thumbnailImage = await thumbnailContainer.$('img');
  var thumbnailProperty = await thumbnailImage.property('src');
  var thumbnail = await thumbnailProperty.jsonValue;

  var titleContainer = await page.$('h1');
  var titleProperty = await titleContainer.property('innerText');
  var title = await titleProperty.jsonValue;

  var paragraphs = await page.$$('p');
  var tagsProperty = await paragraphs[1].property('innerText');
  var tags = await tagsProperty.jsonValue;
  var descriptionProperty = await paragraphs[2].property('innerText');
  var description = await descriptionProperty.jsonValue;
  description = description.replaceAll('+Info »', '');


  newFilms.add(Film(title, description, tags, thumbnail, await findStreamingLink(page)));
}

Future<String> findStreamingLink(Page page) async {
  var streamingElements = await page.$$('table.tableinside');
  var wStreamElement;
  for (var parent in streamingElements) {
    var tableBody = await parent.$('tbody');
    var tableTr = await tableBody.$('tr');
    var tableTd = await tableTr.$('td');
    var tableAnchor = await tableTd.$('a');
    if (tableAnchor == null) continue;
    var streamingPlatformProperty = await tableAnchor.property('innerText');
    var streamingPlatform = (await streamingPlatformProperty.jsonValue)
        .toString();
    if (streamingPlatform == 'Wstream') {
      wStreamElement = tableAnchor;
      break;
    }
  }


  var streamingPlatformProperty = await wStreamElement.property('href');
  var shortUrl = (await streamingPlatformProperty.jsonValue).toString();

  var bypassPage = await browser.newPage();
  await bypassPage.goto(shortUrl, wait: Until.networkIdle);
  if (bypassPage.url.contains('akvideo')) {
    return 'null';
  }

  if (!bypassPage.url.endsWith('.html')) {
    unawaited(bypassPage.evaluate('userViewLink()'));
    await bypassPage.waitForNavigation(wait: Until.networkIdle);

    var url = await _findUrl();
    if(url.startsWith('https://4snip.pw/')) {
      await bypassPage.close();
      bypassPage = await browser.newPage();
      await bypassPage.goto(url, wait: Until.networkIdle);
    }
  }
  
  var url = bypassPage.url;

  var linkParts = url.split('/');
  var tempLink = 'https://wstream.video/video6zvimpy52/' + linkParts[linkParts.length - 1].replaceAll('.html', '');
  await bypassPage.close();

  var finalPage = await browser.newPage();
  await finalPage.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/81.0.4044.113 Safari/537.36');
  await finalPage.goto(tempLink, wait: Until.networkIdle);

  var streamingLink;
  for(var scriptElement in await finalPage.$$('script')){
    var javascriptProperty = await scriptElement.property('innerText');
    var javascriptJson = await javascriptProperty.jsonValue;
    var javascript = await javascriptJson.toString();
    if (javascript.contains('eval')) {
      if(javascript.contains('setTimeout')){
        continue;
      }

      javascript = await javascript.replaceAll('eval(', '');
      javascript = javascript.substring(0, javascript.length - 2);
      var result = await finalPage.evaluate('function test(){return ($javascript).toString();}');
      var expResult = linkExpression.allMatches(result).firstWhere((e) => result.substring(e.start, e.end).contains('.m3u8'));
      streamingLink = result.substring(expResult.start, expResult.end);
    } else if (javascript.contains('hls')) {
      var start = javascript.indexOf('[');
      var end = javascript.indexOf(']');
      streamingLink = javascript.substring(start + 2, end - 1).replaceAll('file:\"', '').replaceAll('\"', '');
    }
  }

  await finalPage.close();
  return streamingLink;
}

Future<dynamic> _findUrl() async{
  return (await browser.pages).last.url;
}