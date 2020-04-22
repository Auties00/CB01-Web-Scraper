import 'dart:async';
import 'dart:io';

import 'package:puppeteer/puppeteer.dart';

import '../template/film.dart';

class FilmManager{
  static final _instance = FilmManager._internal();
  FilmContainer recommendedFilms;
  FilmContainer newFilms;
  var lastTime;
  var updating;
  var scheduled;
  Browser browser;
  bool blockNewPages;

  FilmManager._internal(){
    updating = false;
    scheduled = false;
    blockNewPages = false;
  }

  factory FilmManager(){
    return _instance;
  }

  Future initialize() async {
    if(browser == null) {
      browser = await puppeteer.launch(headless: false, executablePath: 'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe');
      browser.onTargetCreated.listen((element) async {
        if(blockNewPages) {
          var page = await element.page;
          await page?.close();
        }
      });
    }

    updating = true;

    var myPage = await browser.newPage();
    await myPage.goto('https://cb01.expert/', wait: Until.domContentLoaded);

    print('Inizio a raccogliere i dati...');
    var newFilmsTemp = await myPage.$$('li.wa_chpcs_foo_content');

    // ignore: omit_local_variable_types
    List<Film> newFilmsList = [];
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


    // ignore: omit_local_variable_types
    List<Film> recommendedFilmsList = [];
    var elements = await findFilmElementsInPage('https://cb01.expert/');
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

    newFilms = FilmContainer(newFilmsList);;
    recommendedFilms = FilmContainer(recommendedFilmsList);

    lastTime = DateTime.now();

    if(!scheduled){
      Timer.periodic(Duration(days: 1), (timer) async {
        await initialize();
      });
      scheduled = true;
    }

    updating = false;
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

    var streamingElements = await page.$$('table.tableinside');
    var wStreamElement;
    for(var parent in streamingElements) {
      var tableBody = await parent.$('tbody');
      var tableTr = await tableBody.$('tr');
      var tableTd = await tableTr.$('td');
      var tableAnchor = await tableTd.$('a');
      if(tableAnchor == null) continue;
      var streamingPlatformProperty = await tableAnchor.property('innerText');
      var streamingPlatform = (await streamingPlatformProperty.jsonValue).toString();
      if(streamingPlatform == 'Wstream'){
        wStreamElement = tableAnchor;
        break;
      }
    }


    var streamingPlatformProperty = await wStreamElement.property('href');
    var shortUrl = (await streamingPlatformProperty.jsonValue).toString();
    
    var shortPage = await browser.newPage();
    await shortPage.goto(shortUrl, wait: Until.domContentLoaded);
    var shortAnchor = await shortPage.$('a');
    var shortAnchorProperty = await shortAnchor.property('href');
    var shortAnchorValue = (await shortAnchorProperty.jsonValue).toString();
    await shortPage.close();

    var bypassPage = await browser.newPage();
    await bypassPage.goto(shortAnchorValue, wait: Until.networkIdle);

    if(!bypassPage.url.endsWith('.html')) {
      blockNewPages = true;
      var nextButton = await bypassPage.$('button.btn-primary');
      await nextButton.click();
      sleep(Duration(seconds: 4));
      var nextButton1 = await bypassPage.$('button.btn-primary');
      await nextButton1.click();

      await bypassPage.waitForNavigation();

      var nextButton2 = await bypassPage.$('button.btn-primary');
      await nextButton2.click();

      await bypassPage.waitForNavigation(wait: Until.networkIdle);
    }

    var linkParts = bypassPage.url.split('/');
    var tempLink = 'https://wstream.video/video6zvimpy52/' + linkParts[linkParts.length - 1].replaceAll('.html', '');
    await bypassPage.close();
    blockNewPages = false;

    var finalPage = await browser.newPage();
    await finalPage.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/81.0.4044.113 Safari/537.36');
    await finalPage.goto(tempLink, wait: Until.networkIdle);
    var scripts = await finalPage.$$('script');

    var streamingLink;
    for(var scriptElement in scripts){
      var javascriptProperty = await scriptElement.property('innerText');
      var javascriptJson = await javascriptProperty.jsonValue;
      var javascript = await javascriptJson.toString();
      if(javascript.contains('eval')){
        javascript = await javascript.replaceAll('eval(', '');
        javascript = javascript.substring(0, javascript.length - 2);
        var result = await finalPage.evaluate('function test(){return ($javascript).toString();}');
        result = result.replaceAll('jwplayer("vplayer").setup({sources:[{file:"', '');
        result = result.substring(0, result.indexOf('"'));
        streamingLink = result;
      }else if(javascript.contains('hls')){
        var start = javascript.indexOf('[');
        var end = javascript.indexOf(']');
        streamingLink = javascript.substring(start + 2, end - 1);
      }
    }

    print(streamingLink);
    await finalPage.close();
    newFilms.add(Film(title, description, tags, thumbnail, streamingLink));
  }
}