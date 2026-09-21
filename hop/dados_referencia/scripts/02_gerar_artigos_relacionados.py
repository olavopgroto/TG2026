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
#   2. titulos alternativos do ARTIGO PRINCIPAL: busca todos os redirects
#      que apontam para ele e mede as visitas de cada um na janela. Os
#      que tiveram visita relevante entram como alias (a Silver soma a
#      serie deles com a do principal). Isso resolve renomeacao: as
#      visitas de antes da troca de titulo ficam no titulo antigo.
#   3. redirects entre os candidatos: um titulo que HOJE e redirect pode
#      ter sido o titulo real do artigo NA EPOCA do evento (renomeado
#      depois). Regra: o redirect fica se teve mais visitas no pico do
#      que o destino dele; sai se teve menos (era so um atalho).
#   4. monta os 35 artigos de cada evento: principal + 34 do ranking,
#      pulando removidos, redirects mortos, duplicatas e aliases do
#      principal; quem sai e substituido pelo proximo da fila
#   5. busca a data de criacao de cada artigo (primeira revisao, seguindo
#      o redirect ate o artigo real)
#   6. grava em ..\ (dados_referencia):
#        artigos_relacionados.csv   -> lido pela pipeline do Hop
#        artigos_metadados.csv      -> vira silver.artigos
#        log_revisao_aplicada.csv   -> prova de cada decisao
#
# REGRA ZERO x NULO: a data_criacao gravada aqui e o que a Silver usa
# para decidir se um dia sem dado e ZERO (artigo ja existia) ou NULO
# (artigo ainda nao existia). Para os aliases do principal, a data
# gravada e a do principal, porque a serie deles e somada a dele.
#
# MODO TESTE: mude LIMITE_EVENTOS para 1. Os arquivos saem com
# sufixo _TESTE e nao sobrescrevem nada.
# =====================================================================
import shutil

LIMITE_EVENTOS  = None          # None = todos os 40. Use 1 para testar.
ARQ_REMOCOES    = "remocoes.csv"
ARQ_CACHE_DATAS = "cache_datas_criacao.json"
ARQ_CACHE_VIEWS = "cache_visitas_janela.json"   # visitas de aliases e destinos de redirect
DIR_SAIDA       = ".."          # hop\dados_referencia
BUSCAR_API      = os.environ.get("SEM_API") != "1"   # so para teste offline
ARTIGOS_POR_EVENTO = TOP_N      # 35 = principal + 34
LIMIAR_ALIAS    = 0.01          # alias entra se tiver >= 1% das visitas (principal + todos os redirects) na janela
API_WIKI = "https://en.wikipedia.org/w/api.php"
ACESSOS = ["desktop", "mobile-app", "mobile-web"]
AGENTES = ["user", "spider", "automated"]

sufixo = "_TESTE" if LIMITE_EVENTOS else ""
eventos_alvo = eventos[:LIMITE_EVENTOS] if LIMITE_EVENTOS else eventos
nomes_alvo = {e["nome_evento"] for e in eventos_alvo}

def canon(t):
    """Mesma forma de escrita para comparar titulos."""
    return t.replace("_", " ").strip()

def dia_iso(k):
    return f"{k[:4]}-{k[4:6]}-{k[6:8]}"

def janelas(ev):
    d_ev = datetime.date.fromisoformat(ev["data_evento"])
    d_ini = datetime.date.fromisoformat(ev["data_inicio_extracao"])
    d_fim = datetime.date.fromisoformat(ev["data_fim_extracao"])
    return d_ev, d_ini, d_fim

def metricas(serie, ev):
    """Mesma conta do ranking: media antes do evento e media dos 15 dias seguintes."""
    d_ev, d_ini, _ = janelas(ev)
    base = sum(v for k, v in serie.items() if k < fmt(d_ev)) / (d_ev - d_ini).days
    fim_pico = fmt(d_ev + datetime.timedelta(days=DIAS_PICO - 1))
    pico = sum(v for k, v in serie.items() if fmt(d_ev) <= k <= fim_pico) / DIAS_PICO
    razao = round(pico / base, 2) if base > 0 else (999 if pico > 50 else 0)
    return round(base, 2), round(pico, 2), razao

cache_views = json.load(open(ARQ_CACHE_VIEWS, encoding="utf-8")) if os.path.exists(ARQ_CACHE_VIEWS) else {}
def serie_janela(titulo, ev):
    """Visitas diarias do titulo na janela do evento, com cache em disco."""
    chave = f"{ev['nome_evento']}|{titulo}"
    if chave not in cache_views:
        _, d_ini, d_fim = janelas(ev)
        cache_views[chave] = pageviews(titulo, fmt(d_ini), fmt(d_fim))
        time.sleep(PAUSA)
        if len(cache_views) % 50 == 0:
            json.dump(cache_views, open(ARQ_CACHE_VIEWS, "w", encoding="utf-8"), ensure_ascii=False)
    return cache_views[chave]

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

log = []

# ---------- 2. aliases do artigo principal ----------
def redirects_de(titulo):
    lista, cont = [], {}
    while True:
        p = {"action": "query", "format": "json", "prop": "redirects", "titles": titulo,
             "rdnamespace": 0, "rdlimit": "max"}
        p.update(cont)
        d = get(API_WIKI, p)
        if not d:
            break
        for pg in d.get("query", {}).get("pages", {}).values():
            lista += [r["title"] for r in pg.get("redirects", [])]
        if "continue" in d:
            cont = d["continue"]; time.sleep(PAUSA)
        else:
            break
    return lista

principal_info, aliases = {}, {}      # por evento
if BUSCAR_API:
    print("medindo o artigo principal e os titulos alternativos de cada evento...")
    for n, ev in enumerate(eventos_alvo, 1):
        nome, principal = ev["nome_evento"], canon(ev["artigo_wikipedia"])
        s_p = serie_janela(principal, ev)
        tot_p = sum(s_p.values())
        principal_info[nome] = {"serie": s_p, "total": tot_p}
        aliases[nome] = []
        medidos = []
        for r in redirects_de(principal):
            s_r = serie_janela(r, ev)
            medidos.append((r, s_r, sum(s_r.values())))
        total_geral = tot_p + sum(t for _, _, t in medidos)
        for r, s_r, tot_r in medidos:
            if tot_r > 0 and tot_r >= LIMIAR_ALIAS * total_geral:
                aliases[nome].append({"artigo": r, "serie": s_r, "total": tot_r})
                log.append([nome, r, "alias_do_principal",
                            f"{tot_r:,} visitas na janela ({tot_r / total_geral:.0%} do total do evento)"])
        time.sleep(PAUSA)
        json.dump(cache_views, open(ARQ_CACHE_VIEWS, "w", encoding="utf-8"), ensure_ascii=False)
        print(f"   [{n}/{len(eventos_alvo)}] {nome}: principal {tot_p:,} visitas, "
              f"{len(aliases[nome])} alias")

# ---------- 3. redirects entre os candidatos ----------
redirect_para = {}
if BUSCAR_API:
    titulos = sorted({canon(c["artigo"]) for n in nomes_alvo for c in cache.get(n, [])})
    print(f"verificando redirects de {len(titulos)} titulos candidatos...")
    for k in range(0, len(titulos), 50):
        d = get(API_WIKI, {"action": "query", "format": "json", "redirects": 1,
                           "titles": "|".join(titulos[k:k + 50])})
        if d:
            norm = {x["from"]: x["to"] for x in d.get("query", {}).get("normalized", [])}
            for x in d.get("query", {}).get("redirects", []):
                redirect_para[x["from"]] = x["to"]
            for a, b in norm.items():
                if b in redirect_para: redirect_para[a] = redirect_para[b]
        time.sleep(PAUSA)
    print(f"   {len(redirect_para)} redirects encontrados")
else:
    print("AVISO: SEM_API=1, redirects, aliases e datas NAO verificados (so teste offline)")

def redirect_era_titulo_da_epoca(c, ev):
    """True se o redirect teve mais visitas no pico do que o destino dele."""
    destino = redirect_para[canon(c["artigo"])]
    _, pico_destino, _ = metricas(serie_janela(destino, ev), ev)
    return c["media_pico"] > pico_destino, destino, pico_destino

# ---------- 4. selecao dos 35 por evento ----------
selecao = {}
for ev in eventos_alvo:
    nome = ev["nome_evento"]
    principal = canon(ev["artigo_wikipedia"])
    nomes_alias = {a["artigo"] for a in aliases.get(nome, [])}
    escolhidos = [{"artigo": principal, "eh_principal": True, "alias_de": "", "posicao_ranking": 0,
                   "media_base": None, "media_pico": None, "razao": None}]
    vistos = {principal} | nomes_alias
    for pos, c in enumerate(cache.get(nome, []), 1):
        if len(escolhidos) == ARTIGOS_POR_EVENTO:
            break
        art = canon(c["artigo"])
        if (nome, art) in remocoes:
            log.append([nome, art, "removido_revisao", remocoes[(nome, art)]]); continue
        if art in nomes_alias:
            log.append([nome, art, "removido_alias_principal", "ja entra somado ao artigo principal"]); continue
        if art in vistos:
            log.append([nome, art, "removido_duplicata", "ja selecionado neste evento"]); continue
        if art in redirect_para:
            fica, destino, pico_dest = redirect_era_titulo_da_epoca(c, ev)
            if fica:
                log.append([nome, art, "mantido_redirect",
                            f"titulo da epoca: pico {c['media_pico']} contra {pico_dest} de {destino}"])
            else:
                log.append([nome, art, "removido_redirect",
                            f"atalho para {destino}: pico {c['media_pico']} contra {pico_dest}"])
                continue
        if pos >= ARTIGOS_POR_EVENTO:
            log.append([nome, art, "entrou_substituto", f"posicao {pos} do ranking"])
        vistos.add(art)
        escolhidos.append({"artigo": art, "eh_principal": False, "alias_de": "", "posicao_ranking": pos,
                           "media_base": c["media_base"], "media_pico": c["media_pico"],
                           "razao": c["razao"]})
    selecao[nome] = escolhidos
if BUSCAR_API:
    json.dump(cache_views, open(ARQ_CACHE_VIEWS, "w", encoding="utf-8"), ensure_ascii=False)

# ---------- 5. metricas do principal e dos aliases + datas de criacao ----------
def data_criacao(titulo):
    d = get(API_WIKI, {"action": "query", "format": "json", "prop": "revisions", "redirects": 1,
                       "titles": titulo, "rvlimit": 1, "rvdir": "newer", "rvprop": "timestamp"})
    if not d:
        return ""
    for pg in d.get("query", {}).get("pages", {}).values():
        rev = pg.get("revisions")
        if rev:
            return rev[0]["timestamp"][:10]
    return ""

avisos = []
if BUSCAR_API:
    for ev in eventos_alvo:
        nome = ev["nome_evento"]
        p = selecao[nome][0]
        p["media_base"], p["media_pico"], p["razao"] = metricas(principal_info[nome]["serie"], ev)
        for a in aliases[nome]:
            b, pi, r = metricas(a["serie"], ev)
            selecao[nome].append({"artigo": a["artigo"], "eh_principal": False, "alias_de": p["artigo"],
                                  "posicao_ranking": 0, "media_base": b, "media_pico": pi, "razao": r})
        # serie somada (principal + aliases): e ela que a Silver vai usar
        somada = dict(principal_info[nome]["serie"])
        for a in aliases[nome]:
            for k, v in a["serie"].items():
                somada[k] = somada.get(k, 0) + v
        for item in selecao[nome][:1] + [x for x in selecao[nome] if x["alias_de"]]:
            item["primeiro_dia_com_views"] = dia_iso(min(somada)) if somada else ""
        if not somada:
            avisos.append(f"{nome}: SEM NENHUMA VISITA NA JANELA, nem no principal nem nos aliases")
        elif dia_iso(min(somada)) > ev["data_evento"]:
            avisos.append(f"{nome}: evento em {ev['data_evento']}, primeira visita (somada) em "
                          f"{dia_iso(min(somada))} -> dias anteriores serao NULO")

    cache_datas = json.load(open(ARQ_CACHE_DATAS, encoding="utf-8")) if os.path.exists(ARQ_CACHE_DATAS) else {}
    unicos = sorted({a["artigo"] for s in selecao.values() for a in s if not a["alias_de"]})
    faltam = [t for t in unicos if t not in cache_datas]
    print(f"datas de criacao: {len(unicos)} artigos, {len(faltam)} a buscar")
    for i, t in enumerate(faltam, 1):
        cache_datas[t] = data_criacao(t)
        time.sleep(PAUSA)
        if i % 100 == 0 or i == len(faltam):
            json.dump(cache_datas, open(ARQ_CACHE_DATAS, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
            print(f"   ...{i}/{len(faltam)}")
    for nome, s in selecao.items():
        data_principal = cache_datas.get(s[0]["artigo"], "")
        for a in s:
            a["data_criacao"] = data_principal if a["alias_de"] else cache_datas.get(a["artigo"], "")

# ---------- 6. checagens antes de gravar ----------
falhas = []
for nome, s in selecao.items():
    arts = [a["artigo"] for a in s if not a["alias_de"]]
    if len(arts) != ARTIGOS_POR_EVENTO:
        falhas.append(f"{nome}: {len(arts)} artigos (esperado {ARTIGOS_POR_EVENTO}) - cache esgotou")
    todos = [a["artigo"] for a in s]
    if len(set(todos)) != len(todos):
        falhas.append(f"{nome}: artigo repetido")
    for a in todos:
        if (nome, a) in remocoes:
            falhas.append(f"{nome}: removido presente na saida ({a})")
if BUSCAR_API:
    for nome in selecao:
        if principal_info[nome]["total"] + sum(a["total"] for a in aliases[nome]) == 0:
            falhas.append(f"{nome}: artigo principal sem nenhuma visita na janela")
if falhas:
    print("\nERRO - nada foi gravado:")
    for f_ in falhas: print("   ", f_)
    raise SystemExit(1)

# ---------- 7. grava (com backup do que ja existia) ----------
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
    w.writerow(["nome_evento", "categoria", "artigo_wikipedia", "eh_principal", "alias_de",
                "posicao_ranking", "media_base", "media_pico", "razao_amplificacao",
                "data_criacao", "primeiro_dia_com_views"])
    for ev in eventos_alvo:
        for a in selecao[ev["nome_evento"]]:
            w.writerow([ev["nome_evento"], ev["categoria"], a["artigo"].replace(" ", "_"),
                        a["eh_principal"], a["alias_de"].replace(" ", "_"), a["posicao_ranking"],
                        a["media_base"], a["media_pico"], a["razao"],
                        a.get("data_criacao", ""), a.get("primeiro_dia_com_views", "")])

with open(caminho("log_revisao_aplicada.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["nome_evento", "artigo", "acao", "detalhe"])
    w.writerows(log)

# ---------- 8. resumo ----------
n_alias = sum(1 for s in selecao.values() for a in s if a["alias_de"])
esperado = (len(eventos_alvo) * ARTIGOS_POR_EVENTO + n_alias) * len(ACESSOS) * len(AGENTES)
cont = {}
for l in log: cont[l[2]] = cont.get(l[2], 0) + 1
print(f"\nOK - {len(eventos_alvo)} eventos x {ARTIGOS_POR_EVENTO} artigos, mais {n_alias} aliases de principal")
print(f"   artigos_relacionados{sufixo}.csv : {total} linhas (esperado {esperado})")
print(f"   estimativa na Bronze: {total} x 91 dias = {total * 91:,} (teto, a API omite dias sem acesso)")
for k, v in sorted(cont.items()): print(f"   {k}: {v}")
if BUSCAR_API:
    sem_data = sum(1 for s in selecao.values() for a in s if not a.get("data_criacao"))
    print(f"   artigos sem data de criacao: {sem_data}")
    print("\nALIASES DO PRINCIPAL (somados na Silver):")
    for nome in selecao:
        for a in aliases[nome]:
            print(f"    {nome}: {a['artigo']} ({a['total']:,} visitas; principal {principal_info[nome]['total']:,})")
if avisos:
    print("\nATENCAO:")
    for a in avisos: print("   ", a)
