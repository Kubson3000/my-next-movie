# my-next-movie

Projekt startowy do laboratoriów z przedmiotu **Zaawansowane programowanie na platformę iOS**.

Aplikacja rekomenduje filmy. Dane pochodzą z TMDB, konto i zapisane filmy z Supabase.

## Co jest w projekcie

```
MyNextMovie/
  Models/        Movie, gatunki i funkcje pomocnicze
  Services/      MovieLoader, przykładowe filmy
  ViewModels/    stan ekranów listy i wyszukiwania
  Views/         lista, wyszukiwanie i szczegóły filmu, Components/ ze wspólnymi elementami
  Config/        odczyt kluczy API
MyNextMovieTests/        testy jednostkowe (Swift Testing)
docs/                    zadania na kolejne laboratoria
MyNextMovie.xctestplan   plan testów
Config/                  ustawienia builda (.xcconfig), Info.plist
```

Architektura: SwiftUI + MVVM. Nowe pliki dodane do folderów `MyNextMovie/` i `MyNextMovieTests/`.

## Zadania

Zadania na każde zajęcia są w folderze `docs/`:

- [Lab 1: podstawy SwiftUI](docs/lab1.md)
- [Lab 2: ekran wyszukiwania](docs/lab2.md)

Miejsca do uzupełnienia oznacza komentarz `// TODO: Lab N`. Listę wszystkich znajdziesz w Xcode: Find Navigator (⌘⇧F), szukaj `TODO: Lab`.

Testy są dwojakie:

- **gotowe**. Na starcie część z nich nie przechodzi. Przejdą, gdy uzupełnisz kod.
- **do napisania**. Mają `@Test(.disabled(...))` i pustą treść. Komentarz nad testem mówi, co sprawdzić. Napisz test i usuń `.disabled(...)`.

## Konfiguracja Xcode

Ustawienia builda są w plikach `.xcconfig`, a nie w `project.pbxproj`. Łatwo je czytać i porównywać w Git.

```
Config/Shared.xcconfig    wspólne dla całego projektu: wersja iOS, Swift 6, podpisywanie, ostrzeżenia są błędami
Config/Debug.xcconfig     szybki build bez optymalizacji, analizator przy każdym buildzie
Config/Release.xcconfig   build z optymalizacją
Config/App.xcconfig       aplikacja: bundle id, Info.plist, klucze API
Config/Tests.xcconfig     testy jednostkowe
```

Testy uruchamia plan `MyNextMovie.xctestplan`. Zbiera pokrycie kodu (Report navigator, Coverage) i uruchamia testy w losowej kolejności, żeby żaden test nie zależał od innego.

## Wymagania

- Xcode
- GitHub
- TMDB i klucz API
- Supabase

## Start

Robisz to raz, na pierwszych zajęciach.

1. Na GitHubie utwórz **puste, prywatne** repozytorium, np. `my-next-movie`. Bez README i bez `.gitignore`.
2. Sklonuj repozytorium przedmiotu i podepnij swoje:

```sh
git clone https://github.com/fwsoft/my-next-movie.git my-next-movie
cd my-next-movie
git remote rename origin upstream
git remote add origin https://github.com/TWOJ_LOGIN/my-next-movie.git
git push -u origin main
```

3. W swoim repozytorium: Settings, Collaborators. Dodaj prowadzącego.
4. Skopiuj `Config/Secrets.xcconfig.example` jako `Config/Secrets.xcconfig` i wpisz klucze.
5. Otwórz `MyNextMovie.xcodeproj`, uruchom aplikację (⌘R) i testy (⌘U).

## Po każdych zajęciach

Wypchnij aktualny postęp na GitHub, nawet jeśli zadanie nie jest skończone:

```sh
git add .
git commit -m "feat: lab 2, movie list screen"
git push
```


## Nowe laboratoria

Materiały do kolejnych zajęć pojawiają się w repozytorium przedmiotu. Pobierasz je tak:

```sh
git pull --no-rebase --no-edit upstream main
git push
```

`--no-rebase` łączy moje zmiany z Twoimi commitami. Bez tej opcji Git zgłasza błąd `Need to specify how to reconcile divergent branches`. `--no-edit` pomija edytor z opisem commita.

Jeśli Git zgłosi konflikt, popraw zaznaczone pliki, potem `git add` i `git commit`.

## Gdy `git pull upstream main` nie działa

Sprawdź, jakie repozytoria zna Twój projekt:

```sh
git remote -v
```

Poprawnie wygląda to tak:

```
origin    https://github.com/TWOJ_LOGIN/my-next-movie.git
upstream  https://github.com/fwsoft/my-next-movie.git
```

Jeśli jest inaczej, znajdź swój przypadek poniżej.

### Klon repozytorium przedmiotu bez zmiany `origin`

`origin` wskazuje na `fwsoft/my-next-movie`, a `upstream` nie ma. Na GitHubie utwórz **puste, prywatne** repozytorium `my-next-movie`, bez README i bez `.gitignore`. Potem:

```sh
git remote rename origin upstream
git remote add origin https://github.com/TWOJ_LOGIN/my-next-movie.git
git pull --no-rebase --no-edit upstream main
git push -u origin main
```

Dodaj prowadzącego w Settings, Collaborators.

### Fork

`origin` wskazuje na Twojego forka, a `upstream` nie ma. Dodaj go:

```sh
git remote add upstream https://github.com/fwsoft/my-next-movie.git
git pull --no-rebase --no-edit upstream main
git push
```

Fork publicznego repozytorium jest publiczny. Żeby mieć prywatne, utwórz na GitHubie puste, prywatne repozytorium i ustaw je jako `origin`:

```sh
git remote set-url origin https://github.com/TWOJ_LOGIN/my-next-movie.git
git push -u origin main
```

### ZIP albo folder bez Gita

`git remote -v` zgłasza błąd `not a git repository`. Najprościej zacząć od nowa i przenieść swoją pracę:

1. Zmień nazwę starego folderu, np. na `my-next-movie-old`.
2. Wykonaj kroki z sekcji **Start**. Dostaniesz nowy folder z aktualnymi materiałami.
3. Skopiuj ze starego folderu do nowego pliki, które zmieniasz w zadaniach. Nadpisz nimi nowe wersje. Po lab 1 są to:

```
MyNextMovie/Models/Movie.swift
MyNextMovie/Models/Genres.swift
MyNextMovie/Views/MovieCardView.swift
MyNextMovie/Views/MovieListView.swift
MyNextMovie/Views/MovieDetailView.swift
MyNextMovieTests/MovieTests.swift
MyNextMovieTests/MovieListViewModelTests.swift
```

4. Skopiuj `Config/Secrets.xcconfig`, jeśli go masz.
5. Uruchom aplikację i testy. Potem commit i push:

```sh
git add .
git commit -m "feat: lab 1, movie grid and details"
git push
```

Nie kopiuj całego folderu `MyNextMovie/`. Stare wersje nadpiszą pliki, które zmieniły się w kolejnych laboratoriach.

## Klucze API

Klucze wpisujesz w `Config/Secrets.xcconfig`. Ten plik jest w `.gitignore` i nie trafia do repozytorium.

W kodzie odczytujesz je funkcjami z `MyNextMovie/Config/AppConfig.swift`:

```swift
tmdbAPIKey()
supabaseURL()
supabaseAnonKey()
```

## Oddanie projektu

Na koniec semestru oddajesz ZIP z kodem na Moodle.

## Dokumentacja

- Swift: https://docs.swift.org/swift-book
- SwiftUI: https://developer.apple.com/documentation/swiftui
- Swift Testing: https://developer.apple.com/documentation/testing
- TMDB: https://developer.themoviedb.org/docs
- Supabase: https://supabase.com/docs/reference/swift
