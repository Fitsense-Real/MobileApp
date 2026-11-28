# Proveedor de IA SIMULADO (nunca Replicate): responde tarde (RETRASO s) y con error 503, para abrir una ventana entre
# la peticion de generacion y la publicacion. El Backend cae al motor de reglas y llega a publicar (o no).
import http.server, os, time, sys
RETRASO = float(os.environ.get('RETRASO', '20'))
class H(http.server.BaseHTTPRequestHandler):
    def _r(self):
        n = int(self.headers.get('Content-Length') or 0); self.rfile.read(n)
        sys.stdout.write(f'{time.strftime("%H:%M:%S")} IA simulada: {self.command} {self.path} (espera {RETRASO}s)\n'); sys.stdout.flush()
        time.sleep(RETRASO)
        self.send_response(503); self.send_header('Content-Type', 'application/json'); self.end_headers()
        self.wfile.write(b'{"detail":"proveedor simulado no disponible"}')
    do_POST = do_GET = _r
    def log_message(self, *a): pass
http.server.ThreadingHTTPServer(('127.0.0.1', 9999), H).serve_forever()
