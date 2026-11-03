"""Builds reeldrama/assets/demo_catalog.json from Wikimedia Commons metadata.

Usage: python3 tools/build_demo_catalog.py <commons.json>
where commons.json is the raw `prop=videoinfo` API response (see BUILD_INSTRUCTIONS.md).
Every title is a Blender open movie under a Creative Commons license.
"""
import json, math, re, sys, pathlib

EPISODE_SECONDS = 100  # target length of one "short drama" episode

# Original copy written for this app; genres are our own classification.
META = {
    "Big Buck Bunny 4K.webm": ("big-buck-bunny", "Big Buck Bunny", ["Comedy", "Family"], True,
        "A gentle giant of a rabbit just wants a quiet day in the meadow. Three bored rodents decide otherwise, and learn the hard way that kindness has limits."),
    "Sintel movie 4K.webm": ("sintel", "Sintel", ["Fantasy", "Adventure", "Drama"], True,
        "A lone wanderer crosses snowfields and cities searching for the baby dragon she once rescued, and pays a price she never saw coming."),
    "Tears of Steel in 4k - Official Blender Foundation release.webm": ("tears-of-steel", "Tears of Steel", ["Sci-Fi", "Action"], True,
        "In a future Amsterdam overrun by machines, a team of scientists bets everything on replaying one painful breakup."),
    "Elephants Dream (2006).webm": ("elephants-dream", "Elephants Dream", ["Sci-Fi", "Mystery"], False,
        "Two strangers wander a vast mechanical world. One believes it is alive and full of wonders; the other only sees the danger."),
    "Spring - Blender Open Movie.webm": ("spring", "Spring", ["Fantasy", "Drama"], True,
        "A shepherd girl and her loyal dog face ancient spirits to bring the season back to their frozen mountains."),
    "Sprite Fright - Blender Open Movie-full movie.webm": ("sprite-fright", "Sprite Fright", ["Comedy", "Horror"], False,
        "A group of rowdy teens head into the woods for a party and run into the tiny, very territorial guardians of the forest."),
    "Charge - Blender Open Movie-full movie.webm": ("charge", "Charge", ["Sci-Fi", "Action"], False,
        "In a power-starved wasteland, an old man guarding the last working generator meets a desperate intruder."),
    "Coffee Run - Blender Open Movie-full movie.webm": ("coffee-run", "Coffee Run", ["Drama", "Romance"], False,
        "Fuelled by caffeine and heartbreak, a young woman races through memories of a relationship she cannot let go."),
    "HERO - Blender Open Movie-full movie.webm": ("hero", "Hero", ["Action", "Fantasy"], False,
        "Two warriors clash in a showdown of blades and magic that spills across a crumbling ancient city."),
    "WING IT! - Blender Open Movie-full movie.webm": ("wing-it", "Wing It!", ["Comedy", "Family"], False,
        "A barnyard rooster and his friend build a rocket out of junk. What could possibly go wrong?"),
    "SINGULARITY - Blender Open Movie-full movie.webm": ("singularity", "Singularity", ["Sci-Fi", "Mystery"], False,
        "A lone maintenance robot on an abandoned station discovers it may not be as alone as it thought."),
    "Glass Half - Blender Open Movie-full movie.webm": ("glass-half", "Glass Half", ["Comedy"], False,
        "Two art critics in a gallery cannot agree on anything, and their argument gets louder with every painting."),
    "The Daily Dweebs - Blender Open Movie-full movie.webm": ("daily-dweebs", "The Daily Dweebs", ["Comedy", "Family"], False,
        "A mischievous little dog will do anything to avoid a trip to the vet."),
    "Caminandes - Gran Dillama - Blender Foundation's new Open Movie.webm": ("caminandes-gran-dillama", "Caminandes: Gran Dillama", ["Comedy", "Family"], False,
        "Koro the llama spots greener grass on the other side of an electric fence and refuses to take no for an answer."),
}

# Second, independent "server" for one title: Mux's public HLS test stream of Big Buck Bunny.
EXTRA_SERVERS = {"big-buck-bunny": {"server": "Server 2 (HLS)", "quality": "Auto", "format": "hls",
                                    "url": "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"}}


def seek_thumb(thumb_url, seconds):
    base = thumb_url.split("?")[0]
    return re.sub(r"/(\d+)px--", lambda m: f"/{m.group(1)}px-seek%3D{seconds}-", base)


def main(path):
    pages = json.load(open(path))["query"]["pages"].values()
    dramas = []
    for p in pages:
        name = p["title"][5:]
        vi = p["videoinfo"][0]
        did, title, genres, featured, desc = META[name]
        dur = vi["duration"]
        lic = vi["extmetadata"]["LicenseShortName"]["value"]
        ders = {d["src"].split(".")[-3]: d["src"] for d in vi["derivatives"] if d["src"].endswith(".vp9.webm")}
        qualities = [q for q in ("480p", "240p", "720p", "1080p") if q in ders]
        n = max(1, round(dur / EPISODE_SECONDS))
        step = dur / n
        episodes = []
        for i in range(n):
            start, end = round(i * step, 2), round(min(dur, (i + 1) * step), 2)
            sources = [{"server": "Server 1", "quality": q, "format": "webm", "url": ders[q]} for q in qualities]
            if did in EXTRA_SERVERS:
                sources.append(EXTRA_SERVERS[did])
            episodes.append({"number": i + 1, "start": start, "end": end,
                             "thumbnail": seek_thumb(vi["thumburl"], int(start + 5)), "sources": sources})
        dramas.append({
            "id": did, "title": title, "description": desc, "genres": genres, "featured": featured,
            "poster": seek_thumb(vi["thumburl"], int(dur * 0.3)),
            "durationSeconds": round(dur), "license": lic,
            "attribution": "Blender Foundation / Blender Studio",
            "sourcePage": vi["descriptionurl"], "episodes": episodes,
        })
    dramas.sort(key=lambda d: (not d["featured"], d["title"]))
    catalog = {"id": "demo-cc", "name": "Open Movies (CC)",
               "description": "Blender open movies under Creative Commons licenses, split into short episodes.",
               "dramas": dramas}
    out = pathlib.Path(__file__).resolve().parent.parent / "reeldrama/assets/demo_catalog.json"
    out.parent.mkdir(exist_ok=True)
    out.write_text(json.dumps(catalog, indent=1, ensure_ascii=False))
    print(f"{len(dramas)} dramas, {sum(len(d['episodes']) for d in dramas)} episodes -> {out}")


if __name__ == "__main__":
    main(sys.argv[1])
