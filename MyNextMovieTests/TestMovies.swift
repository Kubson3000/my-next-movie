@testable import MyNextMovie

/// Movies written into the tests, so no test needs the network.
@MainActor let testMovies: [Movie] = [
    Movie(
        id: 603,
        title: "The Matrix",
        overview: "A hacker named Neo learns that the world he lives in is a simulation.",
        releaseDate: "1999-03-31",
        posterPath: "/dXNAPwY7VrqMAo51EKhhCJfaGb5.jpg",
        voteAverage: 8.2,
        genreIds: [genreIdAction, genreIdScienceFiction]
    ),
    Movie(
        id: 27205,
        title: "Inception",
        overview: "A thief who steals secrets from dreams is asked to plant an idea instead.",
        releaseDate: "2010-07-15",
        posterPath: "/xlaY2zyzMfkhk0HSC5VUwzoZPU1.jpg",
        voteAverage: 8.4,
        genreIds: [genreIdAction, genreIdScienceFiction, genreIdAdventure]
    ),
    Movie(
        id: 157336,
        title: "Interstellar",
        overview:
            "A team of astronauts travels through a wormhole to find a new home for humanity.",
        releaseDate: "2014-11-05",
        posterPath: "/yQvGrMoipbRoddT0ZR8tPoR7NfX.jpg",
        voteAverage: 8.4,
        genreIds: [genreIdAdventure, genreIdDrama, genreIdScienceFiction]
    ),
    Movie(
        id: 680,
        title: "Pulp Fiction",
        overview: "Several intertwined stories from the Los Angeles criminal underworld.",
        releaseDate: "1994-09-10",
        posterPath: "/vQWk5YBFWF4bZaofAbv0tShwBvQ.jpg",
        voteAverage: 8.5,
        genreIds: [genreIdThriller, genreIdCrime]
    ),
    Movie(
        id: 129,
        title: "Spirited Away",
        overview: "Ten-year-old Chihiro wanders into a world of spirits and must save her parents.",
        releaseDate: "2001-07-20",
        posterPath: "/39wmItIWsg5sZMyRUHLkWBcuVCM.jpg",
        voteAverage: 8.5,
        genreIds: [genreIdAnimation, genreIdFamily, genreIdFantasy]
    ),
    Movie(
        id: 546554,
        title: "Knives Out",
        overview: "A detective investigates the death of a crime novelist on his 85th birthday.",
        releaseDate: "2019-11-27",
        posterPath: "/pThyQovXQrw2m0s9x82twj48Jq4.jpg",
        voteAverage: 7.8,
        genreIds: [genreIdComedy, genreIdCrime, genreIdMystery]
    ),
    Movie(
        id: 597,
        title: "Titanic",
        overview: "A young aristocrat falls in love with a poor artist aboard an ill-fated ship.",
        releaseDate: "1997-12-18",
        posterPath: "/9xjZS2rlVxm8SFx8kPC3aIGCOYQ.jpg",
        voteAverage: 7.9,
        genreIds: [genreIdDrama, genreIdRomance]
    ),
]

private let primeVideo = WatchProvider(
    providerId: 119,
    providerName: "Amazon Prime Video",
    logoPath: "/gMZdpavHmxFNnLpMHwVxfqeux2g.png"
)

/// Details of The Matrix, shortened to one item in every list.
@MainActor let testMovieDetails = MovieDetails(
    id: 603,
    tagline: "Believe the unbelievable.",
    runtime: 136,
    credits: Credits(
        cast: [
            CastMember(
                id: 6384,
                name: "Keanu Reeves",
                character: "Neo",
                profilePath: "/8RZLOyYGsoRe9p44q3xin9QkMHv.jpg"
            )
        ],
        crew: [CrewMember(id: 9340, name: "Lana Wachowski", job: "Director")]
    ),
    videos: VideoList(results: [
        Video(key: "FVI84Dfx2-I", site: "YouTube", type: "Trailer", official: true)
    ]),
    releaseDates: ReleaseDateList(results: [
        CountryReleaseDates(countryCode: "PL", releaseDates: [ReleaseDate(certification: "16")])
    ]),
    watchProviders: WatchProviderList(results: [
        "PL": CountryWatchProviders(
            link: "https://www.themoviedb.org/movie/603-the-matrix/watch?locale=PL",
            flatrate: [primeVideo],
            rent: nil,
            buy: nil
        )
    ]),
    recommendations: TMDBMoviePage(results: [testMovies[1]])
)
