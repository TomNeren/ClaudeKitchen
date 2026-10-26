"""Checks every quote in food-catalog.json against the source text it cites.

Also checks the quotes of the swap rules in rewrite-rules.json next to the catalog.
Each quote must appear verbatim in its source; fragments separated by "…" must appear in order.
Effect quotes must also carry the same relative risk and interval as the data fields.

Usage:
    mkdir -p /tmp/evidence-sources
    curl -sS "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=28446499&rettype=abstract&retmode=text" \
        > /tmp/evidence-sources/schwingshackl-2017.txt
    curl -sSL <url of each dge source in the catalog> > /tmp/evidence-sources/<source id>.html
    python3 -I Scripts/check_evidence_quotes.py Sources/KitchenCore/Resources/Evidence/food-catalog.json \
        /tmp/evidence-sources

Each file in the source directory is named after the source id it holds. Exits non-zero on any failure.
"""
import json, os, re, html, sys
cat, srcdir = sys.argv[1], sys.argv[2]
def norm(t, is_html):
    if is_html:
        t = re.sub(r'(?s)<(script|style)[^>]*>.*?</\1>', '', t)
        t = html.unescape(re.sub(r'<[^>]+>', ' ', t))
    return re.sub(r'\s+', ' ', t.replace('\u00ad', ''))
texts = {}
for f in os.listdir(srcdir):
    texts[f.rsplit('.', 1)[0]] = norm(open(os.path.join(srcdir, f), encoding='utf-8').read(), f.endswith('.html'))
c = json.load(open(cat))
items = [(g['id'], e['sourceID'], e['quote']) for g in c['groups'] for e in g.get('effects', [])]
items += [(t['id'], t['sourceID'], t['quote']) for t in c['targets']]
rules_path = os.path.join(os.path.dirname(cat), 'rewrite-rules.json')
if os.path.exists(rules_path):
    for goal in json.load(open(rules_path, encoding='utf-8'))['goals']:
        items += [(goal['id'] + '/' + r['id'], r['sourceID'], r['quote']) for r in goal['rules']]
bad = 0
for iid, sid, q in items:
    if sid not in texts:
        bad += 1; print("NO SOURCE TEXT", iid, sid); continue
    text = texts[sid]; pos = 0; ok = True
    for frag in [f.strip() for f in q.split('…') if f.strip()]:
        i = text.find(frag, pos)
        if i < 0: ok = False; print('MISSING', iid, sid, repr(frag)); break
        pos = i + len(frag)
    bad += not ok
    print('ok' if ok else 'FAIL', iid)
# numbers inside quotes must match the fields
for g in c['groups']:
    for e in g.get('effects', []):
        nums = re.findall(r'\d+\.\d+', e['quote'])
        if nums[:3] != [f"{e['relativeRisk']:.2f}", f"{e['lower']:.2f}", f"{e['upper']:.2f}"]:
            bad += 1; print('NUMBERS', g['id'], nums)
# every bound of a target must appear as a number in its quote
for t in c['targets']:
    nums = {float(n.replace(',', '.')) for n in re.findall(r'\d+(?:,\d+)?', t['quote'])}
    for key in ('minimum', 'maximum', 'servingGrams'):
        if key in t and float(t[key]) not in nums:
            bad += 1; print('NUMBERS', t['id'], key, t[key])
print("failures:", bad)
sys.exit(1 if bad else 0)
