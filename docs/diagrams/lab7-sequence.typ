#import "_style.typ": *
#show: setup

#chronos.diagram({
  import chronos: *
  _par("model", display-name: "WishSearchViewModel", color: white)
  _par("function", display-name: "movie-filters", color: white)
  _par("database", display-name: "ai_requests", shape: "database", color: white)
  _par("ai", display-name: "OpenRouter", color: outside)
  _par("tmdb", display-name: "TMDB", color: outside)
  _seq("model", "function", comment: [zdanie użytkownika])
  _seq("function", "function", comment: [isSignedInUser])
  _seq("function", "database", comment: [record_ai_request()])
  _seq("database", "function", comment: [pytania z 24 godzin], dashed: true)
  _alt([więcej niż 50], {
    _seq("function", "model", comment: [429, spróbuj jutro], dashed: true)
  }, [w limicie], {
    _seq("function", "ai", comment: [zdanie i schemat JSON])
    _seq("ai", "function", comment: [filtry w JSON], dashed: true)
    _seq("function", "model", comment: [MovieFilters], dashed: true)
  })
  _seq("model", "model", comment: [validatedFilters])
  _alt([są filtry], {
    _seq("model", "tmdb", comment: [searchMoviesByFilters])
  }, [błąd modelu albo brak filtrów], {
    _seq("model", "tmdb", comment: [searchByText, zdanie jako tytuł])
  })
  _seq("tmdb", "model", comment: [\[Movie\]], dashed: true)
})
