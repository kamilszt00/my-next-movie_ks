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
git pull upstream main
git push
```

Jeśli Git zgłosi konflikt, popraw zaznaczone pliki, potem `git add` i `git commit`.

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
