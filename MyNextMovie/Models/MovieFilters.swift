import Foundation

/// What a language model makes of one sentence like "something light with Keanu from the 90s".
/// The model never names movies, it only fills these filters, and TMDB finds the movies.
/// The JSON keys of the movie-filters function are the same as the field names.
nonisolated struct MovieFilters: Codable, Equatable {
    let genreIds: [Int]
    let fromYear: Int  // noYear when there is no lower limit
    let toYear: Int  // noYear when there is no upper limit
    let people: [String]
    let keywords: [String]
    let title: String
}

/// A year limit that is not set.
let noYear = 0
/// The first movies are from about 1880, so an earlier year is a mistake of the model.
let earliestMovieYear = 1880
/// TMDB lists movies announced a few years ahead.
let yearsAheadOfToday = 5
/// Most genres, people or keywords one search uses. More make TMDB find nothing.
let maxFilterValues = 3

/// Filters with nothing set.
let noMovieFilters = MovieFilters(
    genreIds: [], fromYear: noYear, toYear: noYear, people: [], keywords: [], title: "")

/// Goes between the years: "1990–1999".
private let yearRangeDash = "\u{2013}"

/// The current year, for the year range of `validatedFilters`.
func yearOfToday() -> Int {
    return Calendar.current.component(.year, from: Date.now)
}

/// The model's answer with only values the search can use: genres from `genreTable`, years
/// from 1880 to `currentYear` plus 5 in the right order, names without spaces around them
/// and without empty or repeated ones, and at most 3 values of each kind.
func validatedFilters(_ filters: MovieFilters, currentYear: Int) -> MovieFilters {
    let latestYear = currentYear + yearsAheadOfToday
    var fromYear = yearInRange(filters.fromYear, latestYear: latestYear)
    var toYear = yearInRange(filters.toYear, latestYear: latestYear)
    if fromYear != noYear && toYear != noYear && fromYear > toYear {
        swap(&fromYear, &toYear)
    }
    return MovieFilters(
        genreIds: knownUniqueGenreIds(filters.genreIds),
        fromYear: fromYear,
        toYear: toYear,
        people: cleanedNames(filters.people),
        keywords: cleanedNames(filters.keywords),
        title: filters.title.trimmingCharacters(in: .whitespacesAndNewlines)
    )
}

/// Whether the filters say anything about the movies at all.
func hasAnyFilter(_ filters: MovieFilters) -> Bool {
    return !filters.genreIds.isEmpty
        || filters.fromYear != noYear
        || filters.toYear != noYear
        || !filters.people.isEmpty
        || !filters.keywords.isEmpty
        || !filters.title.isEmpty
}

/// Movies with any of the genres and with a release year in the range.
/// No genres or no years match every movie. A movie without a known year does not match years.
func moviesMatchingFilters(_ movies: [Movie], _ filters: MovieFilters) -> [Movie] {
    var matchingMovies: [Movie] = []
    for movie in movies {
        if hasAnyGenre(movie, filters.genreIds) && isReleasedInYears(movie, filters) {
            matchingMovies.append(movie)
        }
    }
    return matchingMovies
}

/// "The Matrix · Comedy · 1990–1999 · Keanu Reeves · heist", only the filters that are set.
func filtersSummary(_ filters: MovieFilters) -> String {
    var parts: [String] = []
    if !filters.title.isEmpty {
        parts.append(filters.title)
    }
    for genreId in filters.genreIds {
        parts.append(genreName(genreId))
    }
    let years = yearRangeText(fromYear: filters.fromYear, toYear: filters.toYear)
    if !years.isEmpty {
        parts.append(years)
    }
    parts += filters.people
    parts += filters.keywords
    return parts.joined(separator: textSeparator)
}

/// "1990–1999", "1990 or later", "up to 1999", "1995" for one year, "" without years.
func yearRangeText(fromYear: Int, toYear: Int) -> String {
    if fromYear == noYear && toYear == noYear {
        return ""
    }
    if toYear == noYear {
        return String(fromYear) + " or later"
    }
    if fromYear == noYear {
        return "up to " + String(toYear)
    }
    if fromYear == toYear {
        return String(fromYear)
    }
    return String(fromYear) + yearRangeDash + String(toYear)
}

/// The year, or `noYear` when it is before the first movies or too far ahead.
private func yearInRange(_ year: Int, latestYear: Int) -> Int {
    if year < earliestMovieYear || year > latestYear {
        return noYear
    }
    return year
}

/// Genre ids that TMDB knows, each once, at most `maxFilterValues`, in the original order.
private func knownUniqueGenreIds(_ genreIds: [Int]) -> [Int] {
    var keptIds: [Int] = []
    for genreId in genreIds {
        if keptIds.count == maxFilterValues {
            break
        }
        if positionInGenreTable(genreId) != genreNotInTable && !keptIds.contains(genreId) {
            keptIds.append(genreId)
        }
    }
    return keptIds
}

/// Names without spaces around them, without empty ones and without repeats in any letter case,
/// at most `maxFilterValues`, in the original order.
private func cleanedNames(_ names: [String]) -> [String] {
    var keptNames: [String] = []
    var keptLowercasedNames: [String] = []
    for name in names {
        if keptNames.count == maxFilterValues {
            break
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedName = trimmedName.lowercased()
        if !trimmedName.isEmpty && !keptLowercasedNames.contains(lowercasedName) {
            keptNames.append(trimmedName)
            keptLowercasedNames.append(lowercasedName)
        }
    }
    return keptNames
}

/// Whether the movie has any of the genres. No genres means any genre.
private func hasAnyGenre(_ movie: Movie, _ genreIds: [Int]) -> Bool {
    if genreIds.isEmpty {
        return true
    }
    for genreId in genreIds {
        if movie.genreIds.contains(genreId) {
            return true
        }
    }
    return false
}

/// Whether the movie came out in the years of the filters. Both ends count.
private func isReleasedInYears(_ movie: Movie, _ filters: MovieFilters) -> Bool {
    if filters.fromYear == noYear && filters.toYear == noYear {
        return true
    }
    guard let year = Int(releaseYear(movie)) else {
        return false
    }
    if filters.fromYear != noYear && year < filters.fromYear {
        return false
    }
    if filters.toYear != noYear && year > filters.toYear {
        return false
    }
    return true
}
