import Foundation
import SwiftData

/// Makes the device and the account have the same saved movies.
/// SwiftData is the source for the screens, the account is a copy in the cloud.
/// Changes that fail to send stay marked and go with the next sync.
///
/// The user can save or remove movies during every `await`, so each step reads
/// the database again after it and carries only movie ids across it.
func syncSavedMovies(_ context: ModelContext, cloud: SavedMoviesCloud) async throws {
    try await sendRemovals(context, cloud: cloud)
    try await mergeAccountMovies(context, cloud: cloud)
    try await uploadNewMovies(context, cloud: cloud)
}

/// The row to send to the account.
func cloudMovieFromSaved(_ savedMovie: SavedMovie) -> CloudSavedMovie {
    return CloudSavedMovie(
        id: savedMovie.movieId,
        title: savedMovie.title,
        overview: savedMovie.overview,
        releaseDate: savedMovie.releaseDate,
        posterPath: savedMovie.posterPath,
        voteAverage: savedMovie.voteAverage,
        genreIds: savedMovie.genreIds,
        savedAt: savedMovie.savedAt
    )
}

func movieFromCloud(_ cloudMovie: CloudSavedMovie) -> Movie {
    return Movie(
        id: cloudMovie.id,
        title: cloudMovie.title,
        overview: cloudMovie.overview,
        releaseDate: cloudMovie.releaseDate,
        posterPath: cloudMovie.posterPath,
        voteAverage: cloudMovie.voteAverage,
        genreIds: cloudMovie.genreIds
    )
}

/// Step 1: removes from the account the movies removed on the device.
private func sendRemovals(_ context: ModelContext, cloud: SavedMoviesCloud) async throws {
    for movieId in removedMovieIds(context) {
        try await cloud.removeMovie(movieId)
        for mark in fetchRemovedMarks(context, movieId: movieId) {
            context.delete(mark)
        }
    }
}

/// Step 2: adds movies from the account to the device, and removes from the device
/// the movies the account no longer has, because another device removed them.
private func mergeAccountMovies(_ context: ModelContext, cloud: SavedMoviesCloud) async throws {
    let cloudMovies = try await cloud.fetchMovies()

    var cloudMovieIds = Set<Int>()
    for cloudMovie in cloudMovies {
        cloudMovieIds.insert(cloudMovie.id)
    }
    for saved in allSavedMovies(context) where saved.isInCloud {
        if !cloudMovieIds.contains(saved.movieId) {
            context.delete(saved)
        }
    }

    // A movie marked as removed waits for step 1 of the next sync.
    let removedIds = Set(removedMovieIds(context))
    for cloudMovie in cloudMovies where !removedIds.contains(cloudMovie.id) {
        addOrMarkInCloud(context, cloudMovie)
    }
}

/// Step 3: sends to the account the movies saved only on the device.
private func uploadNewMovies(_ context: ModelContext, cloud: SavedMoviesCloud) async throws {
    let removedIds = Set(removedMovieIds(context))
    var movieIds: [Int] = []
    var cloudMovies: [CloudSavedMovie] = []
    for saved in allSavedMovies(context) where !saved.isInCloud {
        // Removed and saved again: the old row goes first, in step 1 of the next sync.
        if removedIds.contains(saved.movieId) {
            continue
        }
        movieIds.append(saved.movieId)
        cloudMovies.append(cloudMovieFromSaved(saved))
    }
    if cloudMovies.isEmpty {
        return
    }

    try await cloud.uploadMovies(cloudMovies)

    for movieId in movieIds {
        let savedCopies = fetchSavedMovies(context, movieId: movieId)
        if savedCopies.isEmpty {
            // Removed during the upload, so it has to go from the account too.
            markMovieRemoved(context, movieId: movieId)
        }
        for saved in savedCopies {
            saved.isInCloud = true
        }
    }
}

private func addOrMarkInCloud(_ context: ModelContext, _ cloudMovie: CloudSavedMovie) {
    let savedCopies = fetchSavedMovies(context, movieId: cloudMovie.id)
    if savedCopies.isEmpty {
        let movie = movieFromCloud(cloudMovie)
        context.insert(SavedMovie(movie: movie, savedAt: cloudMovie.savedAt, isInCloud: true))
    }
    for saved in savedCopies {
        saved.isInCloud = true
    }
}

private func allSavedMovies(_ context: ModelContext) -> [SavedMovie] {
    return (try? context.fetch(FetchDescriptor<SavedMovie>())) ?? []
}

private func removedMovieIds(_ context: ModelContext) -> [Int] {
    let marks = (try? context.fetch(FetchDescriptor<RemovedSavedMovie>())) ?? []
    var movieIds: [Int] = []
    for mark in marks {
        movieIds.append(mark.movieId)
    }
    return movieIds
}
