# Buzon SMTP local de pruebas: guarda cada correo como .eml. No reenvia nada.
import sys, time, pathlib
from aiosmtpd.controller import Controller
out = pathlib.Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
class Buzon:
    async def handle_DATA(self, server, session, envelope):
        name = out / f"{time.strftime('%H%M%S')}-{int(time.time()*1000)%1000:03d}-{envelope.rcpt_tos[0]}.eml"
        name.write_bytes(envelope.original_content or envelope.content)
        print('correo para', envelope.rcpt_tos, '->', name.name, flush=True)
        return '250 OK'
c = Controller(Buzon(), hostname='127.0.0.1', port=2525); c.start()
print('buzon SMTP en 127.0.0.1:2525', flush=True)
while True: time.sleep(3600)
