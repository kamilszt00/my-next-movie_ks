import SwiftUI

private let maxCastMembers = 15
private let castItemWidth: CGFloat = 100
private let castPhotoSize: CGFloat = 80
private let providerLogoSize: CGFloat = 44
private let providerLogoCornerRadius: CGFloat = 8
private let recommendationCardWidth: CGFloat = 150
private let trailerButtonCornerRadius: CGFloat = 12

private let symbolNameTrailer = "play.fill"
private let symbolNameCastPlaceholder = "person.fill"
private let justWatchCredit = "Streaming data from JustWatch"

/// Sections shown under the overview on the detail screen.
/// Each section hides itself when it has no data.
struct MovieDetailSections: View {
    let details: MovieDetails

    var body: some View {
        VStack(alignment: .leading, spacing: spacingExtraLarge) {
            TrailerButton(details: details)
            CastRow(cast: Array(details.credits.cast.prefix(maxCastMembers)))
            WhereToWatch(
                countryProviders: watchProviders(details, regionCode: watchRegionCode)
            )
            MoreLikeThis(recommendations: details.recommendations.results)
        }
    }
}

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title).font(.title3.bold())
    }
}

// MARK: - Trailer

private struct TrailerButton: View {
    let details: MovieDetails

    var body: some View {
        if let url = trailerURL(details) {
            Link(destination: url) {
                Label("Watch Trailer", systemImage: symbolNameTrailer)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: trailerButtonCornerRadius))
            }
        }
    }
}

// MARK: - Cast

private struct CastRow: View {
    let cast: [CastMember]

    var body: some View {
        if !cast.isEmpty {
            VStack(alignment: .leading, spacing: spacingMedium) {
                SectionHeader(title: "Cast")
                horizontalRow
            }
        }
    }

    private var horizontalRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: spacingMedium) {
                ForEach(cast) { member in
                    CastMemberCell(member: member)
                }
            }
        }
        .scrollClipDisabled()
    }
}

private struct CastMemberCell: View {
    let member: CastMember

    var body: some View {
        VStack(spacing: spacingSmall) {
            photo
            Text(member.name)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(member.character)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: castItemWidth)
    }

    private var photo: some View {
        AsyncImage(url: profileURL(member)) { phase in
            castImage(for: phase)
        }
        .frame(width: castPhotoSize, height: castPhotoSize)
        .clipShape(Circle())
    }

    @ViewBuilder
    private func castImage(for phase: AsyncImagePhase) -> some View {
        if let image = phase.image {
            image.resizable().scaledToFill()
        } else {
            castPlaceholder
        }
    }

    private var castPlaceholder: some View {
        ZStack {
            Circle().fill(.quaternary)
            Image(systemName: symbolNameCastPlaceholder)
                .foregroundStyle(.secondary)
                .font(.title2)
        }
    }
}

// MARK: - Where to Watch

private struct WhereToWatch: View {
    let countryProviders: CountryWatchProviders

    var body: some View {
        if hasWatchProviders(countryProviders) {
            VStack(alignment: .leading, spacing: spacingMedium) {
                SectionHeader(title: "Where to Watch")
                ProviderGroup(title: "Stream", providers: countryProviders.flatrate)
                ProviderGroup(title: "Rent", providers: countryProviders.rent)
                ProviderGroup(title: "Buy", providers: countryProviders.buy)
                Text(justWatchCredit)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct ProviderGroup: View {
    let title: String
    let providers: [WatchProvider]?

    var body: some View {
        if let providers, !providers.isEmpty {
            VStack(alignment: .leading, spacing: spacingSmall) {
                Text(title).font(.subheadline.weight(.semibold))
                providerRow(for: providers)
            }
        }
    }

    private func providerRow(for providers: [WatchProvider]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacingMedium) {
                ForEach(providers) { provider in
                    ProviderCell(provider: provider)
                }
            }
        }
        .scrollClipDisabled()
    }
}

private struct ProviderCell: View {
    let provider: WatchProvider

    var body: some View {
        HStack(spacing: spacingSmall) {
            logo
            Text(provider.providerName)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, spacingSmall)
        .padding(.vertical, spacingExtraSmall)
        .background(.quaternary, in: Capsule())
    }

    private var logo: some View {
        AsyncImage(url: logoURL(provider)) { loadedImage in
            loadedImage.resizable().scaledToFill()
        } placeholder: {
            Color.secondary.opacity(0.2)
        }
        .frame(width: providerLogoSize, height: providerLogoSize)
        .clipShape(RoundedRectangle(cornerRadius: providerLogoCornerRadius))
    }
}

// MARK: - More Like This

private struct MoreLikeThis: View {
    let recommendations: [Movie]

    var body: some View {
        if !recommendations.isEmpty {
            VStack(alignment: .leading, spacing: spacingMedium) {
                SectionHeader(title: "More Like This")
                horizontalRow
            }
        }
    }

    private var horizontalRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: spacingMedium) {
                ForEach(recommendations) { movie in
                    recommendationCell(for: movie)
                }
            }
        }
        .scrollClipDisabled()
    }

    private func recommendationCell(for movie: Movie) -> some View {
        NavigationLink(value: movie) {
            MovieCardView(movie: movie).frame(width: recommendationCardWidth)
        }
        .buttonStyle(.plain)
    }
}
