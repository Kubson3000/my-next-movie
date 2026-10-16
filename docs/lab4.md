# Lab 4: dane na urządzeniu (SwiftData)

Na tych zajęciach aplikacja zaczyna zapamiętywać dane na telefonie. Dochodzą trzy rzeczy:

- lista filmów do obejrzenia, nowa zakładka Saved,
- historia wyszukiwania na ekranie Search,
- ostatnie odpowiedzi TMDB, pokazywane bez internetu.

Wszystko zapisuje SwiftData, baza danych wbudowana w iOS. Dane zostają po zamknięciu aplikacji.

## Zanim zaczniesz

1. Lab 3 musi być skończony. Aplikacja pobiera filmy z TMDB.

## Nowe pliki

```
MyNextMovie/Storage/StoredModels.swift   modele SwiftData
MyNextMovie/Storage/Storage.swift        zapis i odczyt z bazy
MyNextMovie/Views/SavedMoviesView.swift  zakładka Saved i przycisk zakładki
MyNextMovieTests/StorageTests.swift      testy
```

Zmienione pliki:

```
MyNextMovie/MyNextMovieApp.swift         baza danych dla całej aplikacji
MyNextMovie/Services/TMDB.swift          zapytania z cache na końcu pliku
MyNextMovie/Views/MovieDetailView.swift  przycisk Save na pasku
MyNextMovie/Views/MovieListView.swift    MovieGrid dostępny dla zakładki Saved
MyNextMovie/Views/SearchView.swift       historia wyszukiwania
```

Miejsca do uzupełnienia znajdziesz w Xcode: Find Navigator (⌘⇧F), szukaj `TODO: Lab 4`.

## Jak to działa

Model SwiftData to klasa z `@Model`. Każde jej pole jest kolumną w bazie:

```swift
@Model
final class SavedMovie {
    @Attribute(.unique) var movieId: Int
    var title: String
    var savedAt: Date
    // ...
}
```

`@Attribute(.unique)` pilnuje, żeby jeden film był w bazie najwyżej raz. To klasa, a nie struktura, bo `@Model` tego wymaga.

Bazę tworzy `.modelContainer(for: storedModelTypes)` w `MyNextMovieApp.swift`. Ten kod jest gotowy. Z bazy korzystasz na dwa sposoby:

1. W widoku `@Query` pobiera obiekty i sam odświeża widok, gdy coś się zmieni:

   ```swift
   @Query(sort: \SavedMovie.savedAt, order: .reverse) private var savedMovies: [SavedMovie]
   ```

2. W funkcji dostajesz `ModelContext` i wołasz:

   ```swift
   context.insert(SavedMovie(movie: movie, savedAt: now))  // dodaj
   context.delete(savedMovie)                              // usuń
   try? context.fetch(descriptor)                          // pobierz
   ```

   `FetchDescriptor` mówi, co pobrać. `#Predicate` to warunek, jak `where` w SQL. Przykład jest gotowy w `fetchSavedMovies` w `Storage.swift`.

Zmiany zapisują się same, po chwili. Nie trzeba wołać `save()`. Widok bierze kontekst z `@Environment(\.modelContext)`.

Funkcje w `Storage.swift` dostają `context` jako parametr. Dzięki temu testy podają bazę w pamięci (`makeTestContainer` w `StorageTests.swift`), a aplikacja bazę na urządzeniu. Każdy test ma własną, pustą bazę.

Funkcje dostają też `now`, aktualną datę. Aplikacja podaje `Date.now`, testy stałą datę. Dzięki temu test wie, która data jest nowsza.

## Zadanie 1: lista do obejrzenia

Funkcje w `Storage/Storage.swift`:

1. `toggleSavedMovie`: zapisuje film, a gdy jest już zapisany, usuwa go.
2. `movieFromSaved`: `SavedMovie` z powrotem jako `Movie`, bo widoki i nawigacja używają `Movie`.

Widok `content` w `Views/SavedMoviesView.swift`: komunikat, gdy lista jest pusta, inaczej siatka `MovieGrid` z lab 1.

Przycisk zakładki `SaveMovieButton` jest gotowy. Jest na pasku ekranu szczegółów. Zobacz, jak `@Query` w jego `init` pobiera tylko jeden film.

Dodaj zakładkę. W `MyNextMovieApp.swift`, w `RootView`, między Movies i Search:

```swift
Tab("Saved", systemImage: symbolNameSaved) {
    SavedMoviesView()
}
```

Test do napisania: `SavedMovieTests/savedCopyKeepsEveryField`.

Sprawdź w aplikacji:

1. Zakładka na pasku szczegółów zapisuje film. Ikona się wypełnia.
2. Film jest na zakładce Saved, najnowszy pierwszy.
3. Drugie kliknięcie usuwa film z listy.
4. Zapisane filmy zostają po ponownym uruchomieniu aplikacji. Odczekaj kilka sekund przed zatrzymaniem, bo SwiftData zapisuje zmiany z małym opóźnieniem.

## Zadanie 2: historia wyszukiwania

Funkcje w `Storage/Storage.swift`:

1. `recordSearch`: zapamiętuje wyszukiwanie. To samo wyszukiwanie drugi raz nie tworzy nowego wpisu, tylko przesuwa stary na górę.
2. `removeOldSearches`: zostawia `maxSearchHistoryCount` najnowszych wpisów, resztę usuwa.

Widok `recentSearchRow` w `Views/SearchView.swift`: wiersz z ikoną zegara, który wyszukuje ponownie.

`SearchView` zapisuje wyszukiwanie, gdy użytkownik naciśnie Search (Return) na klawiaturze. Robi to `.onSubmit(of: .search)`. Zapis po każdej literze dałby w historii "m", "ma", "mat". Przed pierwszym wyszukiwaniem ekran pokazuje historię (`SearchStartView`).

Test do napisania: `SearchHistoryTests/repeatedSearchMovesToTop`.

Sprawdź w aplikacji:

1. Wpisz "matrix" i naciśnij Return. Wyczyść pole. "matrix" jest w Recent Searches.
2. Kliknięcie we wpis wyszukuje go ponownie.
3. "Clear" czyści historię.

## Zadanie 3: praca bez internetu

Funkcje w `Storage/Storage.swift`:

1. `storeCachedResponse`: zapisuje JSON z TMDB pod kluczem. Jeden klucz to jedna odpowiedź, nowa zastępuje starą.
2. `fetchWithCacheFallback`: najpierw pyta sieć i zapisuje odpowiedź. Gdy sieć zawiedzie, zwraca zapisaną odpowiedź. Gdy nic nie ma, przekazuje błąd dalej.

Zapytania z cache są gotowe na końcu `Services/TMDB.swift`: `loadPopularMovies(cache:)` i `loadTMDBMovieDetails(movieId:cache:)`. Klucz to `popular` dla listy i `movie/603` dla szczegółów filmu 603.

Te funkcje potrzebują kontekstu, a view modele dostają funkcje bez niego. `RootView` bierze kontekst i opakowuje nimi zapytania. View modele i widoki zostają bez zmian. Zamień `RootView` w `MyNextMovieApp.swift` na:

```swift
private struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            Tab("Movies", systemImage: symbolNameMovies) {
                MovieListView(
                    viewModel: MovieListViewModel(loadMovies: loadPopularMoviesWithCache),
                    loadDetails: loadDetailsWithCache
                )
            }
            Tab("Saved", systemImage: symbolNameSaved) {
                SavedMoviesView(loadDetails: loadDetailsWithCache)
            }
            Tab("Search", systemImage: symbolNameSearch, role: .search) {
                SearchView(
                    viewModel: SearchViewModel(searchMovies: searchTMDBMovies),
                    loadDetails: loadDetailsWithCache
                )
            }
        }
    }

    private func loadPopularMoviesWithCache() async throws -> [Movie] {
        return try await loadPopularMovies(cache: modelContext)
    }

    private func loadDetailsWithCache(movieId: Int) async throws -> MovieDetails {
        return try await loadTMDBMovieDetails(movieId: movieId, cache: modelContext)
    }
}
```

Wyszukiwanie zostaje bez cache. Bez internetu i tak nie znajdzie nowych filmów.

Test do napisania: `ResponseCacheTests/cachedAnswerIsReturnedWhenOffline`.

Sprawdź w aplikacji:

1. Uruchom aplikację z internetem. Otwórz szczegóły dwóch filmów.
2. Wyłącz Wi-Fi w Macu. Zatrzymaj i uruchom aplikację ponownie (⌘R).
3. Lista popularnych filmów jest na ekranie. Szczegóły tych dwóch filmów też.
4. Szczegóły innego filmu pokazują błąd. Tego filmu nie ma w cache.
5. Plakaty mogą się nie pokazać. `AsyncImage` nie zapisuje obrazków na stałe.

## Dokumentacja

- SwiftData: https://developer.apple.com/documentation/swiftdata
- Zapisywanie danych w aplikacji: https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches
- `Query`: https://developer.apple.com/documentation/swiftdata/query
- `ModelContext`: https://developer.apple.com/documentation/swiftdata/modelcontext
- `FetchDescriptor`: https://developer.apple.com/documentation/swiftdata/fetchdescriptor
- `#Predicate`: https://developer.apple.com/documentation/foundation/predicate
- `onSubmit(of:_:)`: https://developer.apple.com/documentation/swiftui/view/onsubmit(of:_:)
