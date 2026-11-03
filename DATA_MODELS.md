# DATA_MODELS

## Catalog JSON (bundled demo + user import format)

The JSON is untrusted input. Validation lives in `lib/core/models.dart`: ids must match `[A-Za-z0-9._-]{1,80}`, URLs must be `http(s)` with a host, an episode's `end` must be greater than its `start`, and malformed dramas are skipped. A catalog with no valid dramas is rejected. Imported catalogs must use **https**, be at most 5 MB, and must not reuse an installed catalog id.

```json
{
  "id": "my-catalog",
  "name": "My Licensed Shorts",
  "description": "optional",
  "dramas": [
    {
      "id": "office-romance",
      "title": "Office Romance",
      "description": "…",
      "poster": "https://cdn.example.com/p/office.jpg",
      "genres": ["Romance", "Comedy"],
      "featured": true,
      "license": "Licensed to me",
      "attribution": "Studio X",
      "sourcePage": "https://example.com/office-romance",
      "episodes": [
        {
          "number": 1,
          "start": 0, "end": 95.5,                 // optional: seconds inside the media file
          "thumbnail": "https://cdn.example.com/t/1.jpg",
          "sources": [
            {"server": "Server 1", "quality": "720p", "format": "hls", "url": "https://cdn.example.com/1/master.m3u8"},
            {"server": "Server 2", "quality": "480p", "url": "https://mirror.example.com/1.mp4"}
          ]
        }
      ]
    }
  ]
}
```
`format` is one of `hls | dash | mp4 | webm`. If omitted, it is inferred from the URL extension. `server` defaults to "Server 1" and `quality` to "Auto". When `start`/`end` are omitted, an episode is the whole file.

## Dart types (`lib/core/models.dart`)
`Catalog{id,name,description,dramas,sourceUrl?}` → `Drama{id,catalogId,catalogName,title,description,poster,genres,featured,license?,attribution?,sourcePage?,episodes}` (unique `key = "$catalogId/$id"`) → `Episode{number,start,end?,thumbnail?,sources}` → `VideoSource{server,quality,format,url}`.
`LibraryItem{dramaKey,title,poster,episode,position,length?,updatedAt}` is a snapshot kept in bookmarks/history, so those still render if a catalog is removed.

## SQLite schema (`lib/data/library_repository.dart`, db `reeldrama.db`, version 1)
| Table | Columns | Notes |
|---|---|---|
| bookmarks | drama_key PK, title, poster, episode, position_ms, length_ms, updated_at | |
| history | same as bookmarks | capped at 100 dramas; position is relative to the episode |
| watched | (drama_key, episode) PK | |
| likes | drama_key PK | local only |
| searches | query PK, at | 10 most recent |
| catalogs | url PK, body, added_at | cached JSON of imported catalogs |
| prefs | key PK, value | `autoplay_next`, `video_fit` (cover/contain), `quality` |

## Repositories (the requested repository roles)
| Requested | Where it lives |
|---|---|
| DramaRepository, SearchRepository, EpisodeRepository | `DramaRepository` (browse, byKey, search, suggestions, related; episodes are part of `Drama`) over the loaded catalogs |
| PlaybackRepository | `CatalogService` (load and validate catalogs) + `pickSource` / `lowestQuality` (source selection) |
| FavoritesRepository, HistoryRepository | `LibraryRepository` (SQLite), exposed to the UI through `LibraryNotifier` |

The replaceable seam is the **catalog JSON contract**. Any backend that serves it (a licensed CMS, your own CDN, a static file) plugs in with no code changes. I grouped the six roles into three classes rather than writing six interfaces with one implementation each. Splitting them later is mechanical.
