#!/usr/bin/env bash
# Usage: deezer_lyrics.sh <arl> <title> <artist>
# Outputs JSON: { "lines": [{time, duration, text, words: [{start, end, word}]}], "found": bool }

ARL="$1"
TITLE="$2"
ARTIST="$3"
UA="Mozilla/5.0 (X11; Linux x86_64; rv:148.0) Gecko/20100101 Firefox/148.0"

fail() { echo '{"found":false,"lines":[]}'; exit 0; }

[ -z "$ARL" ] && fail
[ -z "$TITLE" ] && fail

# 1. Get Bearer JWT — reuse cached if still valid (>30s margin), else refresh
JWT_CACHE="/tmp/qs_deezer_jwt.txt"
JWT=""
if [ -f "$JWT_CACHE" ]; then
    CACHED=$(cat "$JWT_CACHE")
    EXP=$(echo "$CACHED" | python3 -c "
import sys, base64, json
parts = sys.stdin.read().strip().split('.')
if len(parts) >= 2:
    pad = parts[1] + '=' * (-len(parts[1]) % 4)
    print(json.loads(base64.urlsafe_b64decode(pad)).get('exp', 0))
else:
    print(0)
" 2>/dev/null)
    NOW=$(date +%s)
    if [ -n "$EXP" ] && [ "$EXP" -gt $((NOW + 30)) ]; then
        JWT="$CACHED"
    fi
fi

if [ -z "$JWT" ]; then
    JWT=$(curl -s -X POST "https://auth.deezer.com/login/arl?jo=p&rto=c&i=c" \
      -H "Cookie: arl=$ARL" \
      -H "Content-Length: 0" \
      -H "User-Agent: $UA" \
      | python3 -c "import sys,json; print(json.load(sys.stdin)['jwt'])" 2>/dev/null)
    [ -z "$JWT" ] && fail
    echo "$JWT" > "$JWT_CACHE"
fi

# 2. Search track ID
SEARCH_Q=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$TITLE $ARTIST'))" 2>/dev/null)
TRACK_ID=$(curl -s "https://api.deezer.com/search?q=${SEARCH_Q}&limit=1" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data'][0]['id'])" 2>/dev/null)
[ -z "$TRACK_ID" ] && fail

# 3. Fetch word-by-word lyrics via GraphQL
LYRICS=$(curl -s -X POST "https://pipe.deezer.com/api" \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -H "User-Agent: $UA" \
  -d "{\"operationName\":\"GetLyrics\",\"variables\":{\"trackId\":\"$TRACK_ID\"},\"query\":\"query GetLyrics(\$trackId: String!) { track(trackId: \$trackId) { lyrics { synchronizedWordByWordLines { start end words { start end word } } } } }\"}")

# 4. Parse and output — lines with word-level timestamps
echo "$LYRICS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
lines_data = d.get('data', {}).get('track', {}).get('lyrics', {}).get('synchronizedWordByWordLines', [])
if not lines_data:
    print(json.dumps({'found': False, 'lines': []}))
    sys.exit(0)
lines = []
for l in lines_data:
    start_ms = l.get('start', 0)
    end_ms = l.get('end', 0)
    words = [{'start': w['start'] / 1000.0, 'end': w['end'] / 1000.0, 'word': w['word']} for w in l.get('words', [])]
    text = ' '.join(w['word'] for w in l.get('words', []))
    lines.append({
        'time': start_ms / 1000.0,
        'duration': (end_ms - start_ms) / 1000.0,
        'text': text,
        'words': words
    })
print(json.dumps({'found': True, 'lines': lines}))
" 2>/dev/null || fail
