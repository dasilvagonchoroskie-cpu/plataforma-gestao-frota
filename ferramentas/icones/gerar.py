"""Gera os ícones dos apps (Android e web) a partir de motorista.svg e gestor.svg.

Uso: python3 ferramentas/icones/gerar.py   (precisa do Playwright com Chromium)
"""
import pathlib
import re

from playwright.sync_api import sync_playwright

AQUI = pathlib.Path(__file__).resolve().parent
RAIZ = AQUI.parent.parent

APPS = {
    'motorista': {'fundo': '#0B5D3B', 'borda': '#FFFFFF'},
    'gestor': {'fundo': '#1E2427', 'borda': '#F2B300'},
}
DENSIDADES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def arte(app):
    s = (AQUI / f'{app}.svg').read_text()
    return re.search(r'<g id="arte">.*</g>\s*</svg>', s, re.S).group(0).rsplit('</svg>', 1)[0]


def svg(app, tipo):
    c = APPS[app]
    g = arte(app)
    if tipo == 'completo':  # placa de estrada com borda (ícone antigo e web)
        return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
<rect x="16" y="16" width="992" height="992" rx="220" fill="{c['fundo']}"/>
<rect x="66" y="66" width="892" height="892" rx="176" fill="none" stroke="{c['borda']}" stroke-width="24"/>
<g transform="translate(512 512) scale(0.82) translate(-506 -508)">{g}</g></svg>'''
    if tipo == 'mascaravel':  # fundo cheio, arte no círculo seguro (web)
        return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
<rect width="1024" height="1024" fill="{c['fundo']}"/>
<g transform="translate(512 512) scale(0.70) translate(-506 -508)">{g}</g></svg>'''
    # frente do ícone adaptativo (Android 8+): só a arte, fundo transparente
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
<g transform="translate(512 512) scale(0.66) translate(-506 -508)">{g}</g></svg>'''


def main():
    with sync_playwright() as p:
        nav = p.chromium.launch()
        pag = nav.new_page()

        def png(conteudo, lado, destino):
            destino.parent.mkdir(parents=True, exist_ok=True)
            pag.set_viewport_size({'width': lado, 'height': lado})
            pag.set_content(f'<html><body style="margin:0;background:transparent">'
                            f'{conteudo.replace("<svg ", f"<svg width=\'{lado}\' height=\'{lado}\' ", 1)}</body></html>')
            pag.screenshot(path=str(destino), omit_background=True, clip={'x': 0, 'y': 0, 'width': lado, 'height': lado})

        for app, c in APPS.items():
            res = RAIZ / 'apps' / app / 'android' / 'app' / 'src' / 'main' / 'res'
            for nome, d in DENSIDADES.items():
                png(svg(app, 'completo'), round(48 * d), res / f'mipmap-{nome}' / 'ic_launcher.png')
                png(svg(app, 'frente'), round(108 * d), res / f'mipmap-{nome}' / 'ic_launcher_foreground.png')
            (res / 'mipmap-anydpi-v26').mkdir(parents=True, exist_ok=True)
            (res / 'mipmap-anydpi-v26' / 'ic_launcher.xml').write_text(
                '<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@color/ic_launcher_background"/>\n'
                '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
                '    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>\n'
                '</adaptive-icon>\n')
            (res / 'values').mkdir(parents=True, exist_ok=True)
            (res / 'values' / 'cores_icone.xml').write_text(
                '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                f'    <color name="ic_launcher_background">{c["fundo"]}</color>\n</resources>\n')
            png(svg(app, 'completo'), 512, AQUI / f'{app}-512.png')

        web = RAIZ / 'apps' / 'gestor' / 'web'
        png(svg('gestor', 'completo'), 192, web / 'icons' / 'Icon-192.png')
        png(svg('gestor', 'completo'), 512, web / 'icons' / 'Icon-512.png')
        png(svg('gestor', 'mascaravel'), 192, web / 'icons' / 'Icon-maskable-192.png')
        png(svg('gestor', 'mascaravel'), 512, web / 'icons' / 'Icon-maskable-512.png')
        png(svg('gestor', 'completo'), 64, web / 'favicon.png')
        nav.close()


if __name__ == '__main__':
    main()
