import sys, glob, os, re, email
from email import policy
f = sorted(glob.glob(os.path.join(sys.argv[1], '*' + sys.argv[2] + '.eml')))[-1]
m = email.message_from_bytes(open(f, 'rb').read(), policy=policy.default)
body = m.get_body(preferencelist=('plain', 'html')).get_content()
c = re.search(r'^\s*([A-Za-z0-9_-]{30,})\s*$', body, re.M)
print(c.group(1) if c else '')
