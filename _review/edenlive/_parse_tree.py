import json, re, sys

p = r'C:\Users\Sunrise\AppData\Local\Temp\dsh-spill-R9o1jm\session-9648ae962a96\28cadbd78fe3-web_fetch.txt'
s = open(p, encoding='utf-8', errors='replace').read()
i = s.find('{"sha"')
obj, end = json.JSONDecoder().raw_decode(s[i:])
paths = [t['path'] for t in obj['tree']]
print('TOTAL', len(paths), 'truncated', obj.get('truncated'))
pat = re.compile(r'^(realtime/[^/]+$|realtime/(games|apps|integrations_v2|skills)/[^/]+$|docs/[^/]+$|docs/zh/[^/]+$|examples/[^/]+$|examples/samples/[^/]+/[^/]+$)')
for q in paths:
    if pat.match(q):
        print(q)
