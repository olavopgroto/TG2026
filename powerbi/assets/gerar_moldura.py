"""
Gerador das molduras de fundo do dashboard do TCC.

O QUE FAZ
    Desenha, por codigo, a imagem de fundo de cada pagina do Power BI:
    fundo escuro, cabecalho com as abas, barra lateral de filtros e os
    paineis onde os visuais entram. Junto com a imagem, grava um JSON com
    a posicao exata de cada visual, para o encaixe ser feito pelo numero,
    e nao no olho.

    A imagem NAO contem nenhum dado. So fundo, titulos e rotulos fixos.
    Todo numero do dashboard vem dos visuais reais, que ficam por cima.

POR QUE POR CODIGO
    Geradores de imagem comuns acertam a estetica, mas erram posicao:
    retangulos tortos, tamanhos diferentes, texto inventado. Aqui o visual
    precisa cair exatamente sobre o painel desenhado, entao cada retangulo
    tem coordenada fixa.

COORDENADAS
    A tela do Power BI tem 1280 x 720, e e nessa unidade que o painel de
    posicao do visual trabalha. O desenho e feito nessas coordenadas e
    exportado em 3840 x 2160 (4K, mesma proporcao), para ficar nitido em
    tela cheia e em projetor. No Power BI, a imagem entra como plano de
    fundo da pagina com o ajuste "Preencher" e transparencia 0%.

COMO RODAR
    python gerar_moldura.py

    Requisitos: Python 3, Pillow e CairoSVG, e a fonte Inter
    (https://github.com/rsms/inter). O caminho da fonte vem da variavel
    de ambiente INTER_TTF ou, na falta dela, de um Inter-Regular.ttf na
    mesma pasta do script.

    As molduras do projeto foram geradas em ambiente Linux. No Windows, o
    CairoSVG depende da biblioteca Cairo instalada a parte.

PALETA
    A mesma do tema tema_ciclo_atencao.json: verde para o publico, ambar
    para a imprensa, azul para metricas de tempo, roxo para conclusoes e
    cinza para os robos.
"""
import json
import os
from pathlib import Path

import cairosvg
from PIL import ImageFont

PASTA = Path(__file__).resolve().parent
FONTE = os.environ.get("INTER_TTF", str(PASTA / "Inter-Regular.ttf"))

COR = {
    "fundo": "#0F1217",
    "cartao": "#171C24",
    "linha": "#1E232C",
    "borda": "#2A313D",
    "texto": "#EDEFF2",
    "texto2": "#AEB6C2",
    "rotulo": "#8B95A5",
    "apagado": "#6B7686",
    "publico": "#4ADE9E",
    "imprensa": "#F7B955",
    "tempo": "#5BB8E8",
    "conclusao": "#C77DFF",
    "robos": "#7E8AA0",
}

PAGINAS = ["Visão geral", "Subida e queda", "Quem veio primeiro",
           "Assuntos relacionados", "Qualidade dos dados"]

LARG, ALT = 1280, 720          # tela do Power BI
SAIDA_LARG, SAIDA_ALT = 3840, 2160
CAB_ALT = 88                   # cabecalho com titulo e abas
LAT_LARG = 224                 # barra lateral de filtros
MAIN_X = 248                   # inicio da area principal
MAIN_W = LARG - MAIN_X - 24


def largura_texto(txt, tam):
    return ImageFont.truetype(FONTE, tam).getlength(txt)


def esc(t):
    return t.replace("&", "&amp;").replace("<", "&lt;")


def texto(x, y, t, tam, cor, peso=400, ancora="start", esp=0):
    ls = f' letter-spacing="{esp}"' if esp else ""
    return (f'<text x="{x}" y="{y}" font-family="Inter" font-size="{tam}" '
            f'font-weight="{peso}" fill="{cor}" text-anchor="{ancora}"{ls}>{esc(t)}</text>')


def ret(x, y, w, h, cor, r=0, borda=None):
    b = f' stroke="{borda}" stroke-width="1"' if borda else ""
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{cor}"{b}/>'


def base(pagina_ativa, posicoes):
    """Cabecalho, abas e barra lateral: iguais nas cinco paginas."""
    s = [ret(0, 0, LARG, ALT, COR["fundo"])]

    # titulo e selo
    s.append(ret(24, 20, 4, 18, COR["publico"]))
    s.append(texto(38, 35, "Ciclo de vida da atenção digital", 17, COR["texto"], 500))
    selo = "Camada Gold · 40 eventos · 91 dias"
    sw = largura_texto(selo, 11) + 24
    s.append(ret(LARG - 24 - sw, 16, sw, 24, COR["fundo"], 12, COR["borda"]))
    s.append(texto(LARG - 24 - sw / 2, 32, selo, 11, COR["apagado"], ancora="middle"))

    # abas: cada uma recebe por cima um botao invisivel de navegacao
    x = 24
    posicoes["abas"] = []
    for nome in PAGINAS:
        w = largura_texto(nome, 13) + 28
        ativa = nome == pagina_ativa
        s.append(texto(x + w / 2, 75, nome, 13,
                       COR["publico"] if ativa else COR["texto2"], 500 if ativa else 400, "middle"))
        if ativa:
            s.append(ret(x, 85, w, 3, COR["publico"]))
        posicoes["abas"].append({"pagina": nome, "x": round(x), "y": 56,
                                 "largura": round(w), "altura": 32})
        x += w + 2
    s.append(ret(0, CAB_ALT, LARG, 1, COR["linha"]))

    # barra lateral de filtros
    s.append(ret(LAT_LARG, CAB_ALT, 1, ALT - CAB_ALT, COR["linha"]))
    s.append(texto(20, 118, "FILTROS", 11, COR["apagado"], 500, esp=1.2))
    s.append(texto(204, 118, "limpar", 11, COR["publico"], ancora="end"))
    posicoes["botao_limpar"] = {"x": 160, "y": 104, "largura": 50, "altura": 20}

    def filtro(rotulo, y, chave):
        s.append(texto(20, y, rotulo, 11, COR["rotulo"]))
        s.append(ret(20, y + 8, 184, 32, COR["cartao"], 6, COR["borda"]))
        posicoes[chave] = {"x": 20, "y": y + 8, "largura": 184, "altura": 32}

    filtro("Categoria", 148, "filtro_categoria")
    filtro("Evento", 210, "filtro_evento")
    filtro("Ano do evento", 272, "filtro_ano")
    s.append(ret(20, 332, 184, 1, COR["linha"]))
    s.append(texto(20, 358, "DESTA PÁGINA", 11, COR["apagado"], 500, esp=1.2))
    return s


def cartao(s, posicoes, chave, x, y, w, rotulo, cor):
    s.append(ret(x, y, w, 80, COR["cartao"], 8))
    s.append(ret(x, y, w, 3, cor))
    s.append(texto(x + 16, y + 26, rotulo, 12, COR["apagado"]))
    posicoes[chave] = {"x": x + 10, "y": y + 34, "largura": w - 20, "altura": 40}


def painel(s, x, y, w, h, titulo, subtitulo):
    s.append(ret(x, y, w, h, COR["cartao"], 8))
    s.append(texto(x + 20, y + 30, titulo, 14, COR["texto"], 500))
    s.append(texto(x + 20, y + 50, subtitulo, 11, COR["apagado"]))


def pagina_subida_e_queda():
    pos = {}
    s = base("Subida e queda", pos)

    # filtros desta pagina
    s.append(texto(20, 390, "Fase da janela", 11, COR["rotulo"]))
    s.append(ret(20, 398, 184, 32, COR["cartao"], 6, COR["borda"]))
    pos["filtro_fase"] = {"x": 20, "y": 398, "largura": 184, "altura": 32}
    s.append(texto(20, 454, "Agente", 11, COR["rotulo"]))
    pos["filtro_agente"] = {"x": 20, "y": 462, "largura": 184, "altura": 32}

    # quatro cartoes
    gap = 16
    cw = (MAIN_W - 3 * gap) / 4
    itens = [("cartao_visitas", "Visitas do público", COR["publico"]),
             ("cartao_materias", "Matérias", COR["imprensa"]),
             ("cartao_meia_vida", "Meia-vida do público", COR["tempo"]),
             ("cartao_simultaneos", "Eventos simultâneos", COR["conclusao"])]
    for i, (chave, rot, cor) in enumerate(itens):
        cartao(s, pos, chave, round(MAIN_X + i * (cw + gap)), 108, round(cw), rot, cor)

    # painel da curva media
    py, ph = 208, 492
    gw = 640
    painel(s, MAIN_X, py, gw, ph, "Curva média de atenção",
           "todos os eventos, normalizados pelo próprio pico")
    lx, ly = MAIN_X + 20, py + 76
    for nome, cor in [("Público", COR["publico"]), ("Imprensa", COR["imprensa"]), ("Robôs", COR["robos"])]:
        s.append(ret(lx, ly - 4, 16, 3, cor))
        s.append(texto(lx + 22, ly, nome, 11, COR["rotulo"]))
        lx += 22 + largura_texto(nome, 11) + 22
    pos["grafico_curva"] = {"x": MAIN_X + 12, "y": py + 92, "largura": gw - 24, "altura": ph - 104}

    # painel das leituras
    lx0 = MAIN_X + gw + 16
    lw = MAIN_X + MAIN_W - lx0
    painel(s, lx0, py, lw, ph, "Leitura do evento", "quem se moveu primeiro")
    pos["grafico_leitura"] = {"x": lx0 + 12, "y": py + 68, "largura": lw - 24, "altura": ph - 80}

    return s, pos


def exportar(nome_base, elementos, posicoes):
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{SAIDA_LARG}" height="{SAIDA_ALT}" '
           f'viewBox="0 0 {LARG} {ALT}">' + "".join(elementos) + "</svg>")
    cairosvg.svg2png(bytestring=svg.encode("utf-8"),
                     write_to=str(PASTA / f"{nome_base}.png"),
                     output_width=SAIDA_LARG, output_height=SAIDA_ALT)
    with open(PASTA / f"posicoes_{nome_base.removeprefix('moldura_')}.json", "w", encoding="utf-8") as f:
        json.dump(posicoes, f, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    elementos, posicoes = pagina_subida_e_queda()
    exportar("moldura_subida_e_queda", elementos, posicoes)
    print("moldura_subida_e_queda.png e posicoes_subida_e_queda.json gerados em", PASTA)
