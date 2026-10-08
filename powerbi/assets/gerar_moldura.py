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
    "publico": "#BDEAF7",      # azul gelo
    "imprensa": "#2188C5",     # azul royal
    "destaque": "#38BEE8",     # azul ceu: abas, limpar, chegaram juntos
    "robos": "#626F7A",        # cinza azulado escuro
    "secundario": "#95A2AE",   # cinza azulado claro: robos de busca, sem conclusao
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


def base(pagina_ativa, posicoes, filtros_pagina=True):
    """Cabecalho, abas e barra lateral: iguais nas cinco paginas."""
    s = [ret(0, 0, LARG, ALT, COR["fundo"])]

    # titulo e selo
    s.append(ret(24, 20, 4, 18, COR["destaque"]))
    s.append(texto(38, 35, "Ciclo de vida da atenção digital", 17, COR["texto"], 500))
    selo = "40 eventos · de 30 dias antes a 60 depois"
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
                       COR["destaque"] if ativa else COR["texto2"], 500 if ativa else 400, "middle"))
        if ativa:
            s.append(ret(x, 85, w, 3, COR["destaque"]))
        posicoes["abas"].append({"pagina": nome, "x": round(x), "y": 56,
                                 "largura": round(w), "altura": 32})
        x += w + 2
    s.append(ret(0, CAB_ALT, LARG, 1, COR["linha"]))

    # barra lateral de filtros
    s.append(ret(LAT_LARG, CAB_ALT, 1, ALT - CAB_ALT, COR["linha"]))
    s.append(texto(20, 118, "FILTROS", 11, COR["apagado"], 500, esp=1.2))
    s.append(texto(204, 118, "limpar", 11, COR["destaque"], ancora="end"))
    posicoes["botao_limpar"] = {"x": 160, "y": 104, "largura": 50, "altura": 20}

    # plano C: so o rotulo; a caixa e a do proprio filtro do Power BI
    def filtro(rotulo, y, chave):
        s.append(texto(20, y, rotulo, 11, COR["rotulo"]))
        posicoes[chave] = {"x": 20, "y": y + 8, "largura": 184, "altura": 32}

    filtro("Categoria", 148, "filtro_categoria")
    filtro("Evento", 210, "filtro_evento")
    if filtros_pagina:
        s.append(ret(20, 270, 184, 1, COR["linha"]))
        s.append(texto(20, 296, "DESTA PÁGINA", 11, COR["apagado"], 500, esp=1.2))
    return s


def cartao(s, posicoes, chave, x, y, w, rotulo, cor):
    s.append(ret(x, y, w, 80, COR["cartao"], 8))
    s.append(ret(x, y, w, 3, cor))
    tam = 12
    while tam > 9 and largura_texto(rotulo, tam) > w - 28:
        tam -= 0.5
    s.append(texto(x + 16, y + 26, rotulo, tam, COR["apagado"]))
    posicoes[chave] = {"x": x + 10, "y": y + 34, "largura": w - 20, "altura": 40}


def painel(s, x, y, w, h, titulo, subtitulo):
    s.append(ret(x, y, w, h, COR["cartao"], 8))
    s.append(texto(x + 20, y + 30, titulo, 14, COR["texto"], 500))
    s.append(texto(x + 20, y + 50, subtitulo, 11, COR["apagado"]))


def pagina_subida_e_queda():
    pos = {}
    s = base("Subida e queda", pos, filtros_pagina=False)

    gap = 16
    cw = (MAIN_W - 3 * gap) / 4
    itens = [("cartao_visitas", "Visitas do público", COR["publico"]),
             ("cartao_materias", "Matérias da imprensa", COR["imprensa"]),
             ("cartao_meia_vida", "Cai pela metade em", COR["publico"]),
             ("cartao_simultaneos", "Chegaram juntos", COR["destaque"])]
    for i, (chave, rot, cor) in enumerate(itens):
        cartao(s, pos, chave, round(MAIN_X + i * (cw + gap)), 108, round(cw), rot, cor)

    py, ph = 208, 492
    gw = 640
    painel(s, MAIN_X, py, gw, ph, "Como a atenção sobe e cai", "o pico de cada evento vale 100%")
    lx, ly = MAIN_X + 20, py + 76
    for nome, cor in [("Público", COR["publico"]), ("Imprensa", COR["imprensa"]), ("Robôs", COR["robos"])]:
        s.append(ret(lx, ly - 4, 16, 3, cor))
        s.append(texto(lx + 22, ly, nome, 11, COR["rotulo"]))
        lx += 22 + largura_texto(nome, 11) + 22
    pos["grafico_curva"] = {"x": MAIN_X + 12, "y": py + 92, "largura": gw - 24, "altura": ph - 104}

    rx = MAIN_X + gw + 16
    rw = MAIN_X + MAIN_W - rx
    painel(s, rx, py, rw, ph, "Quem veio primeiro", "resultado de cada evento")
    itens = [("Chegaram juntos", COR["destaque"]), ("Imprensa na frente", COR["imprensa"]),
             ("Público na frente", COR["publico"]), ("Sem conclusão", COR["secundario"])]
    lx, ly, limite = rx + 20, py + 74, rx + rw - 16
    for nome, cor in itens:
        w = 14 + largura_texto(nome, 10)
        if lx + w > limite:
            lx, ly = rx + 20, ly + 18
        s.append(ret(lx, ly - 8, 9, 9, cor, 2))
        s.append(texto(lx + 14, ly, nome, 10, COR["rotulo"]))
        lx += w + 14
    topo = ly + 14
    pos["grafico_leitura"] = {"x": rx + 12, "y": round(topo), "largura": rw - 24,
                              "altura": round(py + ph - 8 - topo)}
    return s, pos

def pagina_quem_veio_primeiro():
    pos = {}
    s = base("Quem veio primeiro", pos)

    # filtro desta pagina
    s.append(texto(20, 328, "Forma de comparar", 11, COR["rotulo"]))
    pos["filtro_forma"] = {"x": 20, "y": 336, "largura": 184, "altura": 32}

    # quatro cartoes
    gap = 16
    cw = (MAIN_W - 3 * gap) / 4
    itens = [("cartao_juntos", "Chegaram juntos", COR["destaque"]),
             ("cartao_imprensa", "Imprensa na frente", COR["imprensa"]),
             ("cartao_publico", "Público na frente", COR["publico"]),
             ("cartao_concordam", "Os dois métodos concordam", COR["texto2"])]
    for i, (chave, rot, cor) in enumerate(itens):
        cartao(s, pos, chave, round(MAIN_X + i * (cw + gap)), 108, round(cw), rot, cor)

    # painel do correlograma
    py, ph = 204, 236
    gw = 600
    painel(s, MAIN_X, py, gw, ph, "Em que dia as curvas mais combinam",
           "escolha um evento no filtro · positivo = imprensa antes")
    lx, ly = MAIN_X + 20, py + 72
    s.append(ret(lx, ly - 8, 10, 10, COR["destaque"], 2))
    s.append(texto(lx + 16, ly, "Semelhança das curvas", 11, COR["rotulo"]))
    lx += 16 + largura_texto("Semelhança das curvas", 11) + 24
    s.append(ret(lx, ly - 4, 16, 3, "#9BA5B5"))
    s.append(texto(lx + 22, ly, "Abaixo desta linha pode ser acaso", 11, COR["rotulo"]))
    pos["grafico_correlograma"] = {"x": MAIN_X + 12, "y": py + 80, "largura": gw - 24, "altura": ph - 88}

    # painel do resultado por categoria
    rx = MAIN_X + gw + 16
    rw = MAIN_X + MAIN_W - rx
    painel(s, rx, py, rw, ph, "Resultado por categoria", "quantos eventos em cada resultado")
    # legenda desenhada: as cores sao fixas por resultado, entao nao dependem do dado
    itens = [("Chegaram juntos", COR["destaque"]), ("Imprensa na frente", COR["imprensa"]),
             ("Público na frente", COR["publico"]), ("Sem conclusão", COR["secundario"])]
    lx, ly, limite = rx + 20, py + 74, rx + rw - 16
    for nome, cor in itens:
        w = 14 + largura_texto(nome, 10)
        if lx + w > limite:
            lx, ly = rx + 20, ly + 18
        s.append(ret(lx, ly - 8, 9, 9, cor, 2))
        s.append(texto(lx + 14, ly, nome, 10, COR["rotulo"]))
        lx += w + 14
    topo = ly + 12
    pos["grafico_categoria"] = {"x": rx + 12, "y": round(topo), "largura": rw - 24,
                                "altura": round(py + ph - 8 - topo)}

    # painel da tabela
    ty, th = 456, 244
    painel(s, MAIN_X, ty, MAIN_W, th, "Evento a evento",
           "as duas medidas de cada evento e o resultado final")
    pos["tabela_eventos"] = {"x": MAIN_X + 12, "y": ty + 62, "largura": MAIN_W - 24, "altura": th - 70}

    return s, pos


RAMPA = {"todos": "#5266A0", "dobraram": "#2188C5", "triplicaram": "#38BEE8", "cinco": "#BDEAF7"}


def pagina_assuntos_relacionados():
    pos = {}
    s = base("Assuntos relacionados", pos, filtros_pagina=False)

    # quatro cartoes, um por marca da regua, com legenda comum acima
    s.append(texto(MAIN_X, 106, "artigos relacionados por evento, em média", 10, COR["apagado"]))
    gap = 16
    cw = (MAIN_W - 3 * gap) / 4
    itens = [("cartao_todos", "Todos os artigos", RAMPA["todos"]),
             ("cartao_dobraram", "Dobraram de acesso", RAMPA["dobraram"]),
             ("cartao_triplicaram", "Triplicaram", RAMPA["triplicaram"]),
             ("cartao_cinco", "Cresceram 5 vezes", RAMPA["cinco"])]
    for i, (chave, rot, cor) in enumerate(itens):
        cartao(s, pos, chave, round(MAIN_X + i * (cw + gap)), 116, round(cw), rot, cor)

    # colunas agrupadas por categoria
    py, ph = 214, 270
    painel(s, MAIN_X, py, MAIN_W, ph, "Quanto a atenção se espalha, por tipo de acontecimento",
           "artigos relacionados que passam em cada marca da régua, média por evento")
    lx, ly = MAIN_X + 20, py + 74
    for nome, cor in [("Todos", RAMPA["todos"]), ("Dobraram", RAMPA["dobraram"]),
                      ("Triplicaram", RAMPA["triplicaram"]), ("Cresceram 5 vezes", RAMPA["cinco"])]:
        s.append(ret(lx, ly - 8, 9, 9, cor, 2))
        s.append(texto(lx + 14, ly, nome, 11, COR["rotulo"]))
        lx += 14 + largura_texto(nome, 11) + 22
    pos["grafico_regua"] = {"x": MAIN_X + 12, "y": py + 86, "largura": MAIN_W - 24, "altura": ph - 94}

    # tabela
    ty, th = 500, 200
    painel(s, MAIN_X, ty, MAIN_W, th, "Evento a evento",
           "artigos relacionados que passaram em cada marca da régua")
    pos["tabela_eventos"] = {"x": MAIN_X + 12, "y": ty + 60, "largura": MAIN_W - 24, "altura": th - 68}
    return s, pos


def pagina_qualidade_dos_dados():
    pos = {}
    s = base("Qualidade dos dados", pos, filtros_pagina=False)

    gap = 16
    cw = (MAIN_W - 3 * gap) / 4
    itens = [("cartao_sem_dado", "Dias sem dado no público", COR["texto2"]),
             ("cartao_criado_depois", "Artigo criado depois do evento", COR["texto2"]),
             ("cartao_compara_publico", "Dá para comparar com antes? Público", COR["publico"]),
             ("cartao_compara_imprensa", "Dá para comparar com antes? Imprensa", COR["imprensa"])]
    for i, (chave, rot, cor) in enumerate(itens):
        cartao(s, pos, chave, round(MAIN_X + i * (cw + gap)), 108, round(cw), rot, cor)

    # curva de pessoas e robos
    py, ph = 204, 236
    gw = 600
    painel(s, MAIN_X, py, gw, ph, "Pessoas e robôs reagem ao mesmo evento",
           "curva média, o pico de cada evento vale 100%")
    lx, ly = MAIN_X + 20, py + 72
    for nome, cor in [("Público", COR["publico"]), ("Robôs de busca", COR["secundario"]), ("Outros robôs", COR["robos"])]:
        s.append(ret(lx, ly - 4, 16, 3, cor))
        s.append(texto(lx + 22, ly, nome, 11, COR["rotulo"]))
        lx += 22 + largura_texto(nome, 11) + 22
    pos["grafico_robos"] = {"x": MAIN_X + 12, "y": py + 80, "largura": gw - 24, "altura": ph - 88}

    # painel fixo das auditorias (texto sobre o processo, nao dado de evento)
    ax = MAIN_X + gw + 16
    aw = MAIN_X + MAIN_W - ax
    painel(s, ax, py, aw, ph, "Como estes dados foram conferidos", "auditoria automática da camada final")
    s.append(texto(ax + 20, py + 100, "112", 34, COR["destaque"], 500))
    s.append(texto(ax + 20 + largura_texto("112", 34) + 10, py + 98, "checagens automáticas, nenhum alerta", 12, COR["rotulo"]))
    linhas = ["59 conferem volumes, regras e coerência entre as tabelas",
              "53 refazem cada conta por outro caminho e comparam",
              "1.680 correlações recalculadas uma a uma",
              "6 erros encontrados e corrigidos durante a construção"]
    for i, t in enumerate(linhas):
        s.append(ret(ax + 20, py + 131 + i * 24, 4, 4, COR["borda"], 1))
        s.append(texto(ax + 32, py + 136 + i * 24, t, 11, COR["texto2"]))

    # tabela
    ty, th = 456, 244
    painel(s, MAIN_X, ty, MAIN_W, th, "Evento a evento", "o que falta em cada evento, e por quê")
    pos["tabela_eventos"] = {"x": MAIN_X + 12, "y": ty + 60, "largura": MAIN_W - 24, "altura": th - 68}
    return s, pos


def pagina_visao_geral():
    pos = {}
    s = base("Visão geral", pos, filtros_pagina=False)

    gap = 16
    cw = (MAIN_W - 3 * gap) / 4
    itens = [("cartao_eventos", "Eventos analisados", COR["texto2"]),
             ("cartao_periodo", "Período", COR["texto2"]),
             ("cartao_visitas", "Visitas do público na Wikipédia", COR["publico"]),
             ("cartao_materias", "Matérias da imprensa", COR["imprensa"])]
    for i, (chave, rot, cor) in enumerate(itens):
        cartao(s, pos, chave, round(MAIN_X + i * (cw + gap)), 108, round(cw), rot, cor)

    # eventos por ano
    py, ph = 204, 236
    gw = 440
    painel(s, MAIN_X, py, gw, ph, "Quando os eventos aconteceram", "quantos eventos em cada ano")
    pos["grafico_anos"] = {"x": MAIN_X + 12, "y": py + 62, "largura": gw - 24, "altura": ph - 70}

    # sumario de navegacao (texto fixo sobre o painel, nao dado)
    gx = MAIN_X + gw + 16
    gw2 = MAIN_X + MAIN_W - gx
    painel(s, gx, py, gw2, ph, "Como ler este painel", "uma pergunta em cada página")
    perguntas = [("Subida e queda", "quão rápido a atenção sobe e some?"),
                 ("Quem veio primeiro", "o público ou a imprensa reagiu antes?"),
                 ("Assuntos relacionados", "a atenção se espalha para outros temas?"),
                 ("Qualidade dos dados", "dá para confiar, e onde estão os buracos?")]
    meia = (gw2 - 40) / 2
    for i, (pagina, pergunta) in enumerate(perguntas):
        cx = gx + 20 + (i % 2) * (meia + 20)
        cy = py + 92 + (i // 2) * 66
        s.append(ret(cx, cy - 13, 3, 38, COR["destaque"]))
        s.append(texto(cx + 12, cy, pagina, 12, COR["destaque"], 500))
        s.append(texto(cx + 12, cy + 20, pergunta, 11, COR["texto2"]))

    # tabela
    ty, th = 456, 244
    painel(s, MAIN_X, ty, MAIN_W, th, "Os 40 eventos",
           "uma linha por evento, com o resultado da página Quem veio primeiro")
    pos["tabela_eventos"] = {"x": MAIN_X + 12, "y": ty + 60, "largura": MAIN_W - 24, "altura": th - 68}
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
    import sys
    paginas = {
        "subida_e_queda": pagina_subida_e_queda,
        "quem_veio_primeiro": pagina_quem_veio_primeiro,
        "assuntos_relacionados": pagina_assuntos_relacionados,
        "qualidade_dos_dados": pagina_qualidade_dos_dados,
        "visao_geral": pagina_visao_geral,
    }
    alvo = sys.argv[1] if len(sys.argv) > 1 else None
    if alvo not in paginas:
        print("uso: python gerar_moldura.py <pagina>  |  paginas:", ", ".join(paginas))
        sys.exit(1)
    elementos, posicoes = paginas[alvo]()
    exportar(f"moldura_{alvo}", elementos, posicoes)
    print(f"moldura_{alvo}.png e posicoes_{alvo}.json gerados em", PASTA)
