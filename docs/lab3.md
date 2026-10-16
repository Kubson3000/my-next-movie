# Lab 3: dane z TMDB

Na tych zajęciach aplikacja zaczyna pobierać prawdziwe filmy z TMDB. Lista i wyszukiwanie dostają dane z sieci. Ekran szczegółów pokazuje nowe informacje: czas trwania, reżysera, zwiastun, obsadę, serwisy z filmem i podobne filmy.

Przykładowe filmy z `Services/SampleMovies.swift` zostają. Używają ich podglądy w Xcode i testy, więc działają bez sieci.

## Zanim zaczniesz

1. Lab 2 musi być skończony.
2. Klucz TMDB musi być w `Config/Secrets.xcconfig`. Instrukcja jest w README, w sekcji Klucze API.

## Nowe pliki

```
MyNextMovie/Services/TMDB.swift                   zapytania do TMDB
MyNextMovie/Models/MovieDetails.swift             szczegóły filmu
MyNextMovie/ViewModels/MovieDetailViewModel.swift stan ekranu szczegółów
MyNextMovie/Views/MovieDetailSections.swift       sekcje pod opisem filmu
MyNextMovieTests/TMDBTests.swift                  testy zapytań
MyNextMovieTests/MovieDetailsTests.swift          testy szczegółów
MyNextMovieTests/MovieDetailViewModelTests.swift  testy view modelu
```

Zmienione pliki:

```
MyNextMovie/Services/MovieLoader.swift   nowy typ MovieDetailsLoader
MyNextMovie/Services/SampleMovies.swift  przykładowe szczegóły filmu
MyNextMovie/Views/MovieDetailView.swift  ładuje szczegóły
MyNextMovie/Views/MovieListView.swift    przekazuje loadDetails dalej
MyNextMovie/Views/SearchView.swift       przekazuje loadDetails dalej
MyNextMovie/MyNextMovieApp.swift         miejsce na funkcje TMDB
```

Miejsca do uzupełnienia znajdziesz w Xcode: Find Navigator (⌘⇧F), szukaj `TODO: Lab 3`.

## Jak to działa

TMDB to REST API. Aplikacja wysyła zapytanie `GET` pod adres i dostaje odpowiedź w JSON. Lista popularnych filmów:

```
https://api.themoviedb.org/3/movie/popular?api_key=TWOJ_KLUCZ
```

Odpowiedź wygląda tak (skrócona):

```json
{
  "page": 1,
  "results": [
    {
      "id": 603,
      "title": "The Matrix",
      "release_date": "1999-03-31",
      "poster_path": "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg",
      "vote_average": 8.2,
      "genre_ids": [28, 878]
    }
  ]
}
```

Każde zapytanie to trzy kroki. Wszystkie są w `TMDB.swift`:

1. Adres. `tmdbURL` składa go z `URLComponents`. `URLComponents` zamienia spację i polskie litery na znaki dozwolone w adresie, np. `pan tadeusz` na `pan%20tadeusz`.
2. Wysłanie. `URLSession.shared.data(from:)` czeka na odpowiedź. Funkcja jest `async`, więc ekran w tym czasie działa. `checkTMDBResponse` sprawdza kod HTTP. `200` znaczy OK, `401` zły klucz.
3. Dekodowanie. `JSONDecoder` zamienia JSON na struktury Swift. `Movie` i `MovieDetails` są `Decodable`. Klucze w JSON są w snake_case (`release_date`), a pola w Swift w camelCase (`releaseDate`). Zamienia je `.convertFromSnakeCase`.

Funkcje z TMDB mają te same typy co funkcje z przykładowymi danymi. `fetchPopularMovies` to `MovieLoader`, tak jak `loadSampleMovies`. `searchTMDBMovies` to `MovieSearch`, tak jak `searchSampleMovies`. Dlatego view modele i widoki się nie zmieniają. Zmienia się tylko funkcja podana w `MyNextMovieApp.swift`.

Szczegóły filmu przychodzą w jednym zapytaniu. Parametr `append_to_response` dokleja do odpowiedzi obsadę, filmy wideo, kategorie wiekowe, serwisy i polecane filmy:

```
/3/movie/603?append_to_response=credits,videos,release_dates,watch/providers,recommendations
```

Ekran szczegółów pokazuje film z listy od razu. Szczegóły dochodzą, gdy przyjdą. Ładuje je `MovieDetailViewModel` przez funkcję typu:

```swift
typealias MovieDetailsLoader = (_ movieId: Int) async throws -> MovieDetails
```

## Zadanie 1: zapytania do TMDB

Funkcje w `Services/TMDB.swift`:

1. `tmdbURL`: adres z kluczem API i parametrami.
2. `tmdbSearchURL`: tekst idzie do `/search/movie`, sam gatunek do `/discover/movie`.
3. `decodeTMDBMovies`: lista filmów z JSON.
4. `checkTMDBResponse`: błąd z czytelnym komunikatem, gdy kod HTTP nie jest `200`.

Testy do napisania w `MyNextMovieTests/TMDBTests.swift`:

1. `TMDBTests/searchTextIsPercentEncoded`
2. `TMDBTests/otherErrorResponseShowsStatus`

Po tych funkcjach testy z `TMDBTests.swift` przechodzą. Żaden test nie łączy się z siecią. Testy sprawdzają adresy i dekodują JSON zapisany w pliku testów.

Na koniec podłącz TMDB. W `MyNextMovieApp.swift`, w `RootView`, zamień `loadSampleMovies` na `fetchPopularMovies` i `searchSampleMovies` na `searchTMDBMovies`. Uruchom aplikację. Na liście są popularne filmy z plakatami.

Gdy zamiast filmów widzisz błąd:

- "Missing TMDB API key": nie ma klucza w `Config/Secrets.xcconfig`. Po dodaniu klucza zrób Product, Clean Build Folder (⇧⌘K).
- "TMDB rejected the API key": klucz jest zły. Skopiuj go jeszcze raz z ustawień konta TMDB.

## Zadanie 2: szczegóły filmu

Funkcje w `Models/MovieDetails.swift`:

1. `formattedRuntime`: 136 minut to "2h 16m".
2. `directorNames`: reżyserzy z listy ekipy, każdy raz.
3. `ageCertification`: kategoria wiekowa w kraju, np. "16".
4. `trailerKey`: zwiastun z YouTube, najlepiej oficjalny.

Struktury `Decodable` w tym pliku są gotowe. Przeczytaj je razem z JSON w `MovieDetailsTests.swift`. Zwróć uwagę na `CodingKeys` w `MovieDetails`. Klucz `watch/providers` ma ukośnik, więc nie może być nazwą pola w Swift. `CodingKeys` mówi dekoderowi, które pole odpowiada któremu kluczowi.

Metoda `load` w `ViewModels/MovieDetailViewModel.swift`. Wzoruj się na `load` z `MovieListViewModel`.

Widoki w `Views/MovieDetailSections.swift`:

1. `CastMemberView`: okrągłe zdjęcie aktora, pod nim imię i nazwisko oraz postać.
2. `RecommendationCard`: karta filmu, która otwiera jego szczegóły. Podobna jest w lab 1: `MovieGridItem` w `MovieListView.swift`.

Reszta sekcji jest gotowa. Sprawdzaj widoki w podglądzie (Canvas, ⌥⌘↩) w `MovieDetailSections.swift`. Podgląd używa `sampleMovieDetails`.

Testy do napisania:

1. `MovieDetailsTests/runtimeUnderAnHourHasOnlyMinutes`
2. `MovieDetailsTests/unofficialTrailerWhenNoOfficial`
3. `MovieDetailViewModelTests/loadsDetailsOfItsMovie`

Sprawdź w aplikacji:

1. Szczegóły filmu pokazują hasło filmu, czas trwania i reżysera.
2. "Watch Trailer" otwiera zwiastun na YouTube.
3. Obsada przewija się w bok.
4. "More Like This" otwiera szczegóły kolejnego filmu. Strzałka wstecz wraca do poprzedniego.
5. Wyszukiwanie "matrix" znajduje filmy z TMDB, nie tylko pięć przykładowych.
6. Bez internetu (wyłącz Wi-Fi w Macu) lista pokazuje błąd i przycisk "Try again".

## Dokumentacja

- TMDB, pierwsze kroki: https://developer.themoviedb.org/docs/getting-started
- TMDB, popularne filmy: https://developer.themoviedb.org/reference/movie-popular-list
- TMDB, szczegóły filmu: https://developer.themoviedb.org/reference/movie-details
- `URLComponents`: https://developer.apple.com/documentation/foundation/urlcomponents
- `URLSession`: https://developer.apple.com/documentation/foundation/urlsession
- `JSONDecoder`: https://developer.apple.com/documentation/foundation/jsondecoder
- Kodowanie i dekodowanie własnych typów: https://developer.apple.com/documentation/foundation/encoding-and-decoding-custom-types
- `AsyncImage`: https://developer.apple.com/documentation/swiftui/asyncimage
