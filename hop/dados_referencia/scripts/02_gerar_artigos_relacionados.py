# =====================================================================
# PASSO 2 - Gera artigos_relacionados.csv automaticamente.
#
# Para cada um dos 40 eventos:
#   1. busca todos os artigos que o artigo principal referencia
#   2. mede pageviews de cada candidato na linha de base e no pico
#   3. calcula a razao pico/base (amplificacao)
#   4. guarda os N com maior razao
#
# Roda LOCALMENTE. Demora algumas horas: deixe rodando e va fazer
# outra coisa. Pode ser interrompido e retomado (salva progresso).
# Uso:  python 02_gerar_artigos_relacionados.py
# =====================================================================
import csv, json, os, time, random, datetime, requests

HEADERS = {"User-Agent": "TCC-Fatec-RioPreto/1.0 (olavopgroto15@gmail.com)"}
ARQ_EVENTOS = os.path.join("..", "eventos_curados.csv")   # copia unica, a mesma que o Hop le
ARQ_SAIDA   = "artigos_relacionados.csv"
ARQ_CACHE   = "cache_candidatos.json"   # permite retomar de onde parou

TOP_N          = 35     # quantos artigos relacionados guardar por evento
MAX_CANDIDATOS = 250    # quantos links testar por evento (0 = todos)
PAUSA          = 0.4    # segundos entre chamadas
PAUSA_EVENTO   = 20     # segundos entre eventos
DIAS_PICO      = 15     # janela do pico, a partir da data do evento

S = requests.Session()


def get(url, params=None, tentativas=4):
    """GET com retry e espera progressiva em caso de bloqueio."""
    for i in range(tentativas):
        try:
            r = S.get(url, params=params, headers=HEADERS, timeout=30)
            if r.status_code == 200:
                return r.json()
            if r.status_code == 429:
                espera = 60 * (i + 1)
                print(f"      bloqueio 429, aguardando {espera}s...")
                time.sleep(espera)
                continue
            if r.status_code == 404:
                return None          # artigo sem dado de pageviews
            print(f"      status {r.status_code}, tentativa {i+1}")
            time.sleep(10 * (i + 1))
        except Exception as e:
            print(f"      erro de rede: {e}")
            time.sleep(10 * (i + 1))
    return None


def buscar_links(artigo):
    links, cont = [], {}
    while True:
        p = {"action": "query", "format": "json", "titles": artigo,
             "prop": "links", "plnamespace": 0, "pllimit": "max"}
        p.update(cont)
        d = get("https://en.wikipedia.org/w/api.php", p)
        if d is None:
            break
        for pg in d.get("query", {}).get("pages", {}).values():
            links += [l["title"] for l in pg.get("links", [])]
        if "continue" in d:
            cont = d["continue"]
            time.sleep(PAUSA)
        else:
            break
    return links


def pageviews(artigo, ini, fim):
    a = requests.utils.quote(artigo.replace(" ", "_"), safe="")
    url = (f"https://wikimedia.org/api/rest_v1/metrics/pageviews/per-article/"
           f"en.wikipedia.org/all-access/all-agents/{a}/daily/{ini}/{fim}")
    d = get(url)
    if not d:
        return {}
    return {i["timestamp"][:8]: i["views"] for i in d.get("items", [])}


def fmt(d):
    return d.strftime("%Y%m%d")


cache = json.load(open(ARQ_CACHE, encoding="utf-8")) if os.path.exists(ARQ_CACHE) else {}
eventos = list(csv.DictReader(open(ARQ_EVENTOS, encoding="utf-8")))

for n, ev in enumerate(eventos, 1):
    nome = ev["nome_evento"]
    if nome in cache:
        print(f"[{n}/{len(eventos)}] {nome} - ja processado, pulando")
        continue

    principal = ev["artigo_wikipedia"].replace("_", " ")
    d_evento  = datetime.date.fromisoformat(ev["data_evento"])
    d_ini     = datetime.date.fromisoformat(ev["data_inicio_extracao"])
    base_ini, base_fim = fmt(d_ini), fmt(d_evento - datetime.timedelta(days=1))
    pico_ini, pico_fim = fmt(d_evento), fmt(d_evento + datetime.timedelta(days=DIAS_PICO - 1))
    dias_base = (d_evento - d_ini).days

    print(f"\n[{n}/{len(eventos)}] {nome}")
    print(f"      artigo principal: {principal}")

    links = buscar_links(principal)
    print(f"      links encontrados: {len(links)}")
    if not links:
        print("      NENHUM LINK - verificar titulo ou rede. Evento NAO salvo no cache,")
        print("      sera tentado de novo na proxima execucao.")
        continue

    if MAX_CANDIDATOS and len(links) > MAX_CANDIDATOS:
        random.seed(42)
        links = random.sample(links, MAX_CANDIDATOS)

    resultados = []
    for i, art in enumerate(links, 1):
        base = pageviews(art, base_ini, base_fim)
        time.sleep(PAUSA)
        pico = pageviews(art, pico_ini, pico_fim)
        time.sleep(PAUSA)
        if not pico:
            continue
        m_base = sum(base.values()) / dias_base if base else 0
        m_pico = sum(pico.values()) / DIAS_PICO
        razao  = (m_pico / m_base) if m_base > 0 else (999 if m_pico > 50 else 0)
        resultados.append({"artigo": art, "media_base": round(m_base, 2),
                           "media_pico": round(m_pico, 2), "razao": round(razao, 2)})
        if i % 50 == 0:
            print(f"      ...{i}/{len(links)} candidatos testados")

    resultados.sort(key=lambda x: -x["razao"])
    if len(resultados) < TOP_N * 2:
        print(f"      SO {len(resultados)} candidatos com dado (minimo {TOP_N * 2}).")
        print("      Evento NAO salvo no cache, provavel falha de rede. Rode de novo.")
        continue
    cache[nome] = resultados[:TOP_N * 2]     # guarda o dobro para revisao manual
    json.dump(cache, open(ARQ_CACHE, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"      OK - {len(resultados)} com dado, top razao: {resultados[0]['razao'] if resultados else 0}")
    time.sleep(PAUSA_EVENTO)

# =====================================================================
# PARTE 2 - APLICA A REVISAO E GERA OS ARQUIVOS FINAIS
#
# Roda depois do ranking acima. Se o cache ja tem os 40 eventos, o
# ranking e pulado inteiro e o script cai direto aqui.
#
# O que esta parte faz:
#   1. le remocoes.csv (decisoes da revisao manual, com motivo)
#   2. pergunta a Wikipedia quais candidatos sao redirect
#   3. monta os 35 artigos de cada evento: principal + 34 do ranking,
#      pulando removidos, redirects e duplicatas; quem sai e substituido
#      pelo proximo da fila do cache
#   4. busca a data de criacao de cada artigo (primeira revisao)
#   5. grava em ..\ (dados_referencia):
#        artigos_relacionados.csv   -> lido pela pipeline do Hop
#        artigos_metadados.csv      -> vira silver.artigos
#        log_revisao_aplicada.csv   -> prova de cada remocao/substituicao
#
# REGRA ZERO x NULO: a data_criacao gravada aqui e o que a Silver usa
# para decidir se um dia sem dado e ZERO (artigo ja existia) ou NULO
# (artigo ainda nao existia).
#
# MODO TESTE: mude LIMITE_EVENTOS para 1. Os arquivos saem com
# sufixo _TESTE e nao sobrescrevem nada.
# =====================================================================
import shutil

LIMITE_EVENTOS = None          # None = todos os 40. Use 1 para testar.
ARQ_REMOCOES   = "remocoes.csv"
ARQ_CACHE_DATAS = "cache_datas_criacao.json"
DIR_SAIDA      = ".."          # hop\dados_referencia
BUSCAR_API     = os.environ.get("SEM_API") != "1"   # so para teste offline
ARTIGOS_POR_EVENTO = TOP_N     # 35 = principal + 34
API_WIKI = "https://en.wikipedia.org/w/api.php"
ACESSOS = ["desktop", "mobile-app", "mobile-web"]
AGENTES = ["user", "spider", "automated"]

sufixo = "_TESTE" if LIMITE_EVENTOS else ""
eventos_alvo = eventos[:LIMITE_EVENTOS] if LIMITE_EVENTOS else eventos
nomes_alvo = {e["nome_evento"] for e in eventos_alvo}

def canon(t):
    """Mesma forma de escrita para comparar titulos."""
    return t.replace("_", " ").strip()

print("\n" + "=" * 70)
print("PARTE 2 - aplicando a revisao" + ("  [MODO TESTE]" if sufixo else ""))
print("=" * 70)

# ---------- 1. remocoes ----------
remocoes = {}
for r in csv.DictReader(open(ARQ_REMOCOES, encoding="utf-8")):
    remocoes[(r["nome_evento"], canon(r["artigo"]))] = r["motivo"]

erros = []
for (ev, art) in remocoes:
    if ev not in cache:
        erros.append(f"remocoes.csv cita evento inexistente: {ev}")
    elif not any(canon(c["artigo"]) == art for c in cache[ev]):
        erros.append(f"remocoes.csv cita artigo fora do cache: {ev} | {art}")
if erros:
    print("\nERRO - corrija o remocoes.csv antes de continuar:")
    for e in erros: print("   ", e)
    raise SystemExit(1)
print(f"remocoes.csv: {len(remocoes)} remocoes, todas encontradas no cache")

# ---------- 2. redirects (em lotes de 50 titulos por chamada) ----------
redirect_para = {}
if BUSCAR_API:
    titulos = sorted({canon(c["artigo"]) for n in nomes_alvo for c in cache.get(n, [])})
    print(f"verificando redirects de {len(titulos)} titulos...")
    for k in range(0, len(titulos), 50):
        d = get(API_WIKI, {"action": "query", "format": "json", "redirects": 1,
                           "titles": "|".join(titulos[k:k + 50])})
        if d:
            norm = {x["from"]: x["to"] for x in d.get("query", {}).get("normalized", [])}
            for x in d.get("query", {}).get("redirects", []):
                redirect_para[x["from"]] = x["to"]
            for a, b in norm.items():           # normalizado que tambem e redirect
                if b in redirect_para: redirect_para[a] = redirect_para[b]
        time.sleep(PAUSA)
    print(f"   {len(redirect_para)} redirects encontrados")
else:
    print("AVISO: SEM_API=1, redirects e datas NAO verificados (so teste offline)")

# ---------- 3. selecao dos 35 por evento ----------
selecao, log = {}, []
for ev in eventos_alvo:
    nome = ev["nome_evento"]
    principal = canon(ev["artigo_wikipedia"])
    escolhidos = [{"artigo": principal, "eh_principal": True, "posicao_ranking": 0,
                   "media_base": None, "media_pico": None, "razao": None}]
    vistos = {principal}
    for pos, c in enumerate(cache.get(nome, []), 1):
        if len(escolhidos) == ARTIGOS_POR_EVENTO:
            break
        art = canon(c["artigo"])
        if (nome, art) in remocoes:
            log.append([nome, art, "removido_revisao", remocoes[(nome, art)]]); continue
        if art in redirect_para:
            log.append([nome, art, "removido_redirect", f"redireciona para {redirect_para[art]}"]); continue
        if art in vistos:
            log.append([nome, art, "removido_duplicata", "ja selecionado neste evento"]); continue
        if pos >= ARTIGOS_POR_EVENTO:     # entrou alem da posicao 34 = substituto
            log.append([nome, art, "entrou_substituto", f"posicao {pos} do ranking"])
        vistos.add(art)
        escolhidos.append({"artigo": art, "eh_principal": False, "posicao_ranking": pos,
                           "media_base": c["media_base"], "media_pico": c["media_pico"],
                           "razao": c["razao"]})
    selecao[nome] = escolhidos

# ---------- 4. metricas do principal + datas de criacao ----------
def data_criacao(titulo):
    d = get(API_WIKI, {"action": "query", "format": "json", "prop": "revisions",
                       "titles": titulo, "rvlimit": 1, "rvdir": "newer",
                       "rvprop": "timestamp"})
    if not d:
        return ""
    for pg in d.get("query", {}).get("pages", {}).values():
        rev = pg.get("revisions")
        if rev:
            return rev[0]["timestamp"][:10]
    return ""

avisos_principal = []
if BUSCAR_API:
    for ev in eventos_alvo:
        p = selecao[ev["nome_evento"]][0]
        d_evento = datetime.date.fromisoformat(ev["data_evento"])
        d_ini = datetime.date.fromisoformat(ev["data_inicio_extracao"])
        d_fim = datetime.date.fromisoformat(ev["data_fim_extracao"])
        serie = pageviews(p["artigo"], fmt(d_ini), fmt(d_fim))
        time.sleep(PAUSA)
        base = sum(v for k, v in serie.items() if k < fmt(d_evento)) / (d_evento - d_ini).days
        fim_pico = fmt(d_evento + datetime.timedelta(days=DIAS_PICO - 1))
        pico = sum(v for k, v in serie.items() if fmt(d_evento) <= k <= fim_pico) / DIAS_PICO
        p["media_base"], p["media_pico"] = round(base, 2), round(pico, 2)
        p["razao"] = round(pico / base, 2) if base > 0 else (999 if pico > 50 else 0)
        p["primeiro_dia_com_views"] = (min(serie)[:4] + "-" + min(serie)[4:6] + "-" + min(serie)[6:8]) if serie else ""

    cache_datas = json.load(open(ARQ_CACHE_DATAS, encoding="utf-8")) if os.path.exists(ARQ_CACHE_DATAS) else {}
    unicos = sorted({a["artigo"] for s in selecao.values() for a in s})
    faltam = [t for t in unicos if t not in cache_datas]
    print(f"datas de criacao: {len(unicos)} artigos, {len(faltam)} a buscar")
    for i, t in enumerate(faltam, 1):
        cache_datas[t] = data_criacao(t)
        time.sleep(PAUSA)
        if i % 100 == 0 or i == len(faltam):
            json.dump(cache_datas, open(ARQ_CACHE_DATAS, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
            print(f"   ...{i}/{len(faltam)}")
    for s in selecao.values():
        for a in s:
            a["data_criacao"] = cache_datas.get(a["artigo"], "")

    # principal criado ou renomeado dentro da janela = aviso para a analise
    for ev in eventos_alvo:
        p = selecao[ev["nome_evento"]][0]
        if p.get("primeiro_dia_com_views") and p["primeiro_dia_com_views"] > ev["data_inicio_extracao"]:
            tipo = ("RENOMEADO (existia antes com outro titulo)"
                    if p["data_criacao"] and p["data_criacao"] < p["primeiro_dia_com_views"]
                    else "CRIADO dentro da janela")
            avisos_principal.append(f"{ev['nome_evento']}: evento em {ev['data_evento']}, "
                                    f"views a partir de {p['primeiro_dia_com_views']}, "
                                    f"criado em {p['data_criacao']} -> {tipo}")

# ---------- 5. checagens antes de gravar ----------
falhas = []
for nome, s in selecao.items():
    arts = [a["artigo"] for a in s]
    if len(arts) != ARTIGOS_POR_EVENTO:
        falhas.append(f"{nome}: {len(arts)} artigos (esperado {ARTIGOS_POR_EVENTO}) - cache esgotou")
    if len(set(arts)) != len(arts):
        falhas.append(f"{nome}: artigo repetido")
    for a in arts:
        if (nome, a) in remocoes:
            falhas.append(f"{nome}: removido presente na saida ({a})")
if falhas:
    print("\nERRO - nada foi gravado:")
    for f_ in falhas: print("   ", f_)
    raise SystemExit(1)

# ---------- 6. grava (com backup do que ja existia) ----------
def caminho(nome_arq):
    base, ext = os.path.splitext(nome_arq)
    return os.path.join(DIR_SAIDA, base + sufixo + ext)

for arq in ["artigos_relacionados.csv", "artigos_metadados.csv", "log_revisao_aplicada.csv"]:
    if os.path.exists(caminho(arq)):
        shutil.copy2(caminho(arq), caminho(arq) + ".bak")

total = 0
with open(caminho("artigos_relacionados.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["nome_evento", "categoria", "artigo_wikipedia", "tipo_acesso", "tipo_agente",
                "data_inicio_extracao", "data_fim_extracao"])
    for ev in eventos_alvo:
        for a in selecao[ev["nome_evento"]]:
            for ac in ACESSOS:
                for ag in AGENTES:
                    w.writerow([ev["nome_evento"], ev["categoria"], a["artigo"].replace(" ", "_"),
                                ac, ag, ev["data_inicio_extracao"], ev["data_fim_extracao"]])
                    total += 1

with open(caminho("artigos_metadados.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["nome_evento", "categoria", "artigo_wikipedia", "eh_principal", "posicao_ranking",
                "media_base", "media_pico", "razao_amplificacao", "data_criacao"])
    for ev in eventos_alvo:
        for a in selecao[ev["nome_evento"]]:
            w.writerow([ev["nome_evento"], ev["categoria"], a["artigo"].replace(" ", "_"),
                        a["eh_principal"], a["posicao_ranking"], a["media_base"], a["media_pico"],
                        a["razao"], a.get("data_criacao", "")])

with open(caminho("log_revisao_aplicada.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["nome_evento", "artigo", "acao", "detalhe"])
    w.writerows(log)

# ---------- 7. resumo ----------
esperado = len(eventos_alvo) * ARTIGOS_POR_EVENTO * len(ACESSOS) * len(AGENTES)
cont = {}
for l in log: cont[l[2]] = cont.get(l[2], 0) + 1
print(f"\nOK - {len(eventos_alvo)} eventos x {ARTIGOS_POR_EVENTO} artigos")
print(f"   artigos_relacionados{sufixo}.csv : {total} linhas (esperado {esperado})")
print(f"   estimativa na Bronze: {total} x 91 dias = {total * 91:,} (teto, a API omite dias sem acesso)")
for k, v in sorted(cont.items()): print(f"   {k}: {v}")
if BUSCAR_API:
    sem_data = sum(1 for s in selecao.values() for a in s if not a.get("data_criacao"))
    print(f"   artigos sem data de criacao: {sem_data}")
if avisos_principal:
    print("\nATENCAO - artigo principal sem views no inicio da janela:")
    for a in avisos_principal: print("   ", a)
