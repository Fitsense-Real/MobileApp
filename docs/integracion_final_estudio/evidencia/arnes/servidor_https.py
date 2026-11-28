import http.server, ssl, sys, os
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'www'))
class H(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Content-Type', 'text/plain; charset=utf-8') if self.path.endswith('.txt') else None
        super().end_headers()
    def log_message(self, *a): pass
srv = http.server.HTTPServer(('127.0.0.1', 8443), H)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER); ctx.load_cert_chain('../cert.pem', '../key.pem')
srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
srv.serve_forever()
