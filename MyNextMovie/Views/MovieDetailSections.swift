import SwiftUI

/// The Cast row shows at most this many actors.
private let maximumCastCount = 15

private let castPhotoSize: CGFloat = 72
private let castMemberWidth: CGFloat = 88
private let castTextMaxLines = 2
private let providerLogoSize: CGFloat = 48
private let providerWidth: CGFloat = 72
private let providerNameMaxLines = 2
private let recommendedCardWidth: CGFloat = 130

private let symbolNamePlayTrailer = "play.fill"
private let symbolNameNoPhoto = "person.fill"

/// TMDB terms of use require this line under streaming data.
private let justWatchAttribution = "Streaming data from JustWatch"

/// Trailer, cast, streaming services and similar movies under the movie overview.
/// A section shows only when TMDB has data for it.
struct MovieDetailSections: View {
    let details: MovieDetails

    var body: some View {
        VStack(alignment: .leading, spacing: spacingExtraLarge) {
            if let trailerAddress = trailerURL(details) {
                TrailerButton(trailerAddress: trailerAddress)
            }
            if !details.credits.cast.isEmpty {
                CastSection(cast: Array(details.credits.cast.prefix(maximumCastCount)))
            }
            if hasWatchProviders(providersInRegion) {
                WatchProvidersSection(countryProviders: providersInRegion)
            }
            if !details.recommendations.results.isEmpty {
                RecommendationsSection(movies: details.recommendations.results)
            }
        }
    }

    private var providersInRegion: CountryWatchProviders {
        watchProviders(details, regionCode: watchRegionCode)
    }
}

/// Opens the trailer on YouTube.
private struct TrailerButton: View {
    let trailerAddress: URL

    var body: some View {
        Link(destination: trailerAddress) {
            Label("Watch Trailer", systemImage: symbolNamePlayTrailer)
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}

/// A heading with the section content under it.
private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacingMedium) {
            Text(title)
                .font(.headline)
            content()
        }
    }
}

/// Items in one row that scrolls sideways when they do not fit, like the genre chips.
private struct SidewaysRow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: spacingMedium) {
                content()
            }
        }
        .scrollClipDisabled()
    }
}

private struct CastSection: View {
    let cast: [CastMember]

    var body: some View {
        DetailSection(title: "Cast") {
            castRow
        }
    }

    private var castRow: some View {
        SidewaysRow {
            ForEach(cast) { castMember in
                CastMemberView(castMember: castMember)
            }
        }
    }
}

/// A round photo of the actor with the name and the character under it.
private struct CastMemberView: View {
    let castMember: CastMember

    var body: some View {
        VStack(spacing: spacingExtraSmall) {
            photo
            Text(castMember.name)
                .font(.caption.weight(.semibold))
                .lineLimit(castTextMaxLines)
            Text(castMember.character)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(castTextMaxLines)
        }
        .multilineTextAlignment(.center)
        .frame(width: castMemberWidth)
    }

    /// `AsyncImage` shows the placeholder also when there is no photo or it fails to load.
    private var photo: some View {
        AsyncImage(url: profileURL(castMember)) { loadedImage in
            loadedImage.resizable().scaledToFill()
        } placeholder: {
            noPhoto
        }
        .frame(width: castPhotoSize, height: castPhotoSize)
        .clipShape(Circle())
    }

    private var noPhoto: some View {
        Image(systemName: symbolNameNoPhoto)
            .font(.title)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.quaternary)
    }
}

/// Services in the phone's country, grouped into Stream, Rent and Buy.
private struct WatchProvidersSection: View {
    let countryProviders: CountryWatchProviders

    var body: some View {
        DetailSection(title: "Where to Watch") {
            ProviderGroup(title: "Stream", providers: countryProviders.flatrate ?? [])
            ProviderGroup(title: "Rent", providers: countryProviders.rent ?? [])
            ProviderGroup(title: "Buy", providers: countryProviders.buy ?? [])
            Text(justWatchAttribution)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

/// One way to watch, e.g. Stream, with its services in a row. Nothing when it has no services.
private struct ProviderGroup: View {
    let title: String
    let providers: [WatchProvider]

    @ViewBuilder
    var body: some View {
        if !providers.isEmpty {
            group
        }
    }

    private var group: some View {
        VStack(alignment: .leading, spacing: spacingSmall) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            providerRow
        }
    }

    private var providerRow: some View {
        SidewaysRow {
            ForEach(providers) { provider in
                ProviderView(provider: provider)
            }
        }
    }
}

/// A service logo with its name under it.
private struct ProviderView: View {
    let provider: WatchProvider

    var body: some View {
        VStack(spacing: spacingExtraSmall) {
            logo
            Text(provider.providerName)
                .font(.caption2)
                .lineLimit(providerNameMaxLines)
        }
        .multilineTextAlignment(.center)
        .frame(width: providerWidth)
    }

    private var logo: some View {
        AsyncImage(url: logoURL(provider)) { loadedImage in
            loadedImage.resizable().scaledToFill()
        } placeholder: {
            Rectangle().fill(.quaternary)
        }
        .frame(width: providerLogoSize, height: providerLogoSize)
        .clipShape(RoundedRectangle(cornerRadius: thumbnailCornerRadius, style: .continuous))
    }
}

/// Recommended movies as cards in a row.
private struct RecommendationsSection: View {
    let movies: [Movie]

    var body: some View {
        DetailSection(title: "More Like This") {
            movieRow
        }
    }

    private var movieRow: some View {
        SidewaysRow {
            ForEach(movies) { movie in
                RecommendedMovie(movie: movie)
            }
        }
    }
}

/// One recommended movie. Tapping it opens its details, like a movie in the grid.
private struct RecommendedMovie: View {
    let movie: Movie

    var body: some View {
        NavigationLink(value: movie) {
            MovieCardView(movie: movie)
                .frame(width: recommendedCardWidth)
        }
        .buttonStyle(.plain)
    }
}
