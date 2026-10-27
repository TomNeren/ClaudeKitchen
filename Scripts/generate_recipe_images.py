"""Generates one food photo per bundled recipe with the Black Forest Labs (BFL) API.

Model: FLUX.2 [pro] (POST https://api.bfl.ai/v1/flux-2-pro, the model BFL recommends as default).
Flow: POST returns id + polling_url, poll until status "Ready", download result.sample at once
(the signed URL is only valid for 10 minutes). Output is 1024x1280 (4:5) JPEG.

Each image is shrunk with macOS `sips` (max 1200 px long side, JPEG quality 80) and written to
App/Sources/Assets.xcassets/recipe-<id>.imageset/ together with a Contents.json.

Usage:
    export BFL_API_KEY=...            # never commit or print the key
    python3 -I Scripts/generate_recipe_images.py --dry-run
    python3 -I Scripts/generate_recipe_images.py --only ajapsandali,borschtsch
    python3 -I Scripts/generate_recipe_images.py --force

By default recipes whose imageset already holds an image are skipped.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

API_HOST = "https://api.bfl.ai"
ENDPOINT = API_HOST + "/v1/flux-2-pro"
WIDTH, HEIGHT = 1024, 1280  # 4:5, both multiples of 16
MAX_LONG_SIDE = 1200
JPEG_QUALITY = 80
REQUEST_DELAY = 2.0  # seconds between recipes
POLL_INTERVAL = 1.5
POLL_TIMEOUT = 240
MAX_RETRIES = 6

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RECIPES_DIR = os.path.join(ROOT, "Sources", "KitchenCore", "Resources", "Recipes")
ASSETS_DIR = os.path.join(ROOT, "App", "Sources", "Assets.xcassets")

# One fixed style for the whole set, so all photos look like one cookbook.
STYLE_TEMPLATE = (
    "Editorial food photography, shot from a 45 degree angle slightly above. "
    "{dish}, served in a simple ceramic bowl or plate on a warm linen and wood surface. "
    "{details}"
    "Soft natural window light from the left, shallow depth of field, "
    "muted warm palette of cream, terracotta and sage. "
    "Natural, appetising, realistic textures. "
    "No text, no hands, no logos, no cutlery clutter."
)

# Pantry staples that do not help the picture.
SKIP_INGREDIENT = re.compile(r"(öl|salz|pfeffer|wasser|brühe|zucker|mehl)\b", re.IGNORECASE)


def build_prompt(recipe):
    """Builds the image prompt from name, cuisine/type tag and main ingredients."""
    parts = [p.strip() for p in recipe.get("tag", "").split("·") if p.strip()]
    dish = recipe["name"]
    if parts:
        dish += " (" + ", ".join(parts) + ")"
    names = []
    for ing in recipe.get("ingredients", []):
        name = ing["name"].split(",")[0].strip()
        if name and not SKIP_INGREDIENT.search(name) and name not in names:
            names.append(name)
    details = "Visible ingredients: " + ", ".join(names[:6]) + ". " if names else ""
    return STYLE_TEMPLATE.format(dish=dish, details=details)


def load_recipes():
    recipes = []
    for fn in sorted(os.listdir(RECIPES_DIR)):
        if fn.endswith(".json"):
            with open(os.path.join(RECIPES_DIR, fn), encoding="utf-8") as f:
                recipes.append(json.load(f))
    return recipes


def imageset_dir(rid):
    return os.path.join(ASSETS_DIR, "recipe-%s.imageset" % rid)


def image_path(rid):
    return os.path.join(imageset_dir(rid), "recipe-%s.jpg" % rid)


def http(url, key, body=None):
    """One request with 429/5xx backoff. Returns the raw response bytes."""
    delay = 5.0
    for attempt in range(MAX_RETRIES):
        headers = {"accept": "application/json", "x-key": key}
        data = None
        if body is not None:
            headers["Content-Type"] = "application/json"
            data = json.dumps(body).encode("utf-8")
        req = urllib.request.Request(url, data=data, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                return resp.read()
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503, 504) and attempt < MAX_RETRIES - 1:
                wait = float(e.headers.get("Retry-After") or delay)
                print("   Server meldet %d, neuer Versuch in %.0f s ..." % (e.code, wait))
                time.sleep(wait)
                delay = min(delay * 2, 60)
                continue
            detail = e.read().decode("utf-8", "replace")[:300]
            raise RuntimeError("HTTP %d: %s" % (e.code, detail))
        except urllib.error.URLError as e:
            if attempt < MAX_RETRIES - 1:
                print("   Netzwerkfehler (%s), neuer Versuch in %.0f s ..." % (e.reason, delay))
                time.sleep(delay)
                delay = min(delay * 2, 60)
                continue
            raise RuntimeError("Netzwerkfehler: %s" % e.reason)
    raise RuntimeError("zu viele Versuche")


def generate(prompt, key):
    """Submits the task, polls until Ready and returns the JPEG bytes."""
    task = json.loads(http(ENDPOINT, key, {
        "prompt": prompt,
        "width": WIDTH,
        "height": HEIGHT,
        "output_format": "jpeg",
    }))
    polling_url = task["polling_url"]
    start = time.time()
    while time.time() - start < POLL_TIMEOUT:
        time.sleep(POLL_INTERVAL)
        result = json.loads(http(polling_url, key))
        status = result.get("status")
        if status == "Ready":
            # Download immediately: the signed URL expires after 10 minutes.
            # The signed URL needs no API key header, so it is fetched without one.
            with urllib.request.urlopen(result["result"]["sample"], timeout=120) as resp:
                return resp.read()
        if status in ("Error", "Failed", "Request Moderated", "Content Moderated", "Task not found"):
            raise RuntimeError("Generierung fehlgeschlagen (Status: %s)" % status)
    raise RuntimeError("Zeitüberschreitung beim Warten auf das Bild")


def write_imageset(rid, jpeg_bytes):
    os.makedirs(imageset_dir(rid), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        raw = os.path.join(tmp, "raw.jpg")
        with open(raw, "wb") as f:
            f.write(jpeg_bytes)
        subprocess.run(
            ["sips", "-s", "format", "jpeg", "-s", "formatOptions", str(JPEG_QUALITY),
             "-Z", str(MAX_LONG_SIDE), raw, "--out", image_path(rid)],
            check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    contents = {
        "images": [{"filename": "recipe-%s.jpg" % rid, "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(imageset_dir(rid), "Contents.json"), "w", encoding="utf-8") as f:
        json.dump(contents, f, indent=2)
        f.write("\n")


def main():
    ap = argparse.ArgumentParser(description="Rezeptbilder mit FLUX.2 [pro] erzeugen.")
    ap.add_argument("--only", help="Kommagetrennte Rezept-IDs (Slugs)")
    ap.add_argument("--force", action="store_true", help="Vorhandene Bilder überschreiben")
    ap.add_argument("--dry-run", action="store_true", help="Nur Prompts ausgeben, kein API-Aufruf")
    args = ap.parse_args()

    recipes = load_recipes()
    if args.only:
        wanted = [s.strip() for s in args.only.split(",") if s.strip()]
        known = {r["id"] for r in recipes}
        unknown = [s for s in wanted if s not in known]
        if unknown:
            sys.exit("Unbekannte Rezept-IDs: " + ", ".join(unknown))
        recipes = [r for r in recipes if r["id"] in wanted]

    # Tolerate a key exported with an extra pair of quotes.
    key = os.environ.get("BFL_API_KEY", "").strip().strip("\"'").strip()
    if not key and not args.dry_run:
        sys.exit("Fehler: Umgebungsvariable BFL_API_KEY ist nicht gesetzt. "
                 "Bitte den BFL-API-Schlüssel exportieren: export BFL_API_KEY=...")

    done = skipped = failed = 0
    total = len(recipes)
    for i, r in enumerate(recipes, 1):
        rid = r["id"]
        prefix = "[%d/%d] %s" % (i, total, rid)
        prompt = build_prompt(r)
        if args.dry_run:
            print("%s\n   %s\n" % (prefix, prompt))
            continue
        if os.path.exists(image_path(rid)) and not args.force:
            print("%s: übersprungen (Bild vorhanden)" % prefix)
            skipped += 1
            continue
        print("%s: erzeuge Bild ..." % prefix)
        try:
            write_imageset(rid, generate(prompt, key))
            print("   fertig: %s" % os.path.relpath(image_path(rid), ROOT))
            done += 1
        except (RuntimeError, subprocess.CalledProcessError, KeyError, OSError) as e:
            print("   FEHLER: %s" % e)
            failed += 1
        time.sleep(REQUEST_DELAY)

    if not args.dry_run:
        print("\nFertig: %d erzeugt, %d übersprungen, %d fehlgeschlagen." % (done, skipped, failed))
        sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
