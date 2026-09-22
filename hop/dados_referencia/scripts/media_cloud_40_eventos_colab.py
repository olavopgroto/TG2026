# =====================================================================
# EXTRACAO MEDIA CLOUD - 40 EVENTOS x 10 PAISES
#
# Diferenca para a versao anterior: os eventos NAO estao mais escritos
# no codigo. O script le o eventos_curados.csv (a mesma copia que o Hop
# e o script 02 usam), entao query e datas nunca divergem entre os dois.
#
# ANTES DE RODAR: suba o eventos_curados.csv para o Google Drive em
#   MyDrive/tcc_referencia/eventos_curados.csv
#
# Saida: um JSON por evento x pais em MyDrive/tcc_media_cloud_bruto,
# no mesmo formato que o extracao_bronze_cobertura_midia.hpl ja le.
#
# Retomada: arquivo que ja existe e bate com a query e a janela do CSV
# e pulado. Se a query ou a janela mudou, ele e extraido de novo.
# Cole cada celula separada no Colab, na ordem.
# =====================================================================

# ---------- CELULA 1: instalacao e Drive ----------
!pip install mediacloud -q
from google.colab import drive
drive.mount('/content/drive')

# ---------- CELULA 2: configuracao ----------
import mediacloud.api, datetime, json, time, pathlib, csv
from google.colab import userdata

mc = mediacloud.api.SearchApi(userdata.get('MC_API_KEY'))

ARQ_EVENTOS = pathlib.Path("/content/drive/MyDrive/tcc_referencia/eventos_curados.csv")
OUT_DIR     = pathlib.Path("/content/drive/MyDrive/tcc_media_cloud_bruto")
OUT_DIR.mkdir(parents=True, exist_ok=True)
LOG_FALHAS  = OUT_DIR / "falhas.log"

PAISES = {
    34412234: "United States", 34412257: "Brazil", 34412476: "United Kingdom",
    34412409: "Germany", 34412118: "India", 34412193: "China",
    34412056: "Japan", 34412238: "South Africa", 34412282: "Australia",
    34412131: "Turkey",
}

eventos = []
for r in csv.DictReader(open(ARQ_EVENTOS, encoding="utf-8")):
    eventos.append({
        "nome_evento": r["nome_evento"], "categoria": r["categoria"],
        "palavra_chave": r["palavra_chave_busca"],
        "data_inicio": datetime.date.fromisoformat(r["data_inicio_extracao"]),
        "data_fim": datetime.date.fromisoformat(r["data_fim_extracao"]),
    })
print(f"{len(eventos)} eventos lidos do CSV x {len(PAISES)} paises = {len(eventos) * len(PAISES)} arquivos")
assert len(eventos) == 40, "o CSV deveria ter 40 eventos, confira o arquivo no Drive"

# ---------- CELULA 3: extracao com retomada segura ----------
def caminho(ev, pais):
    return OUT_DIR / f"{ev['nome_evento'].replace(' ', '_')}_{pais.replace(' ', '_')}.json"

def arquivo_valido(ev, pais):
    """Existe E foi gerado com a mesma query e a mesma janela do CSV atual."""
    p = caminho(ev, pais)
    if not p.exists():
        return False
    try:
        d = json.load(open(p, encoding="utf-8"))
        datas = [x["date"] for x in d["payload"]]
        return (d["query_utilizada"] == ev["palavra_chave"]
                and datas and min(datas) == ev["data_inicio"].isoformat()
                and max(datas) == ev["data_fim"].isoformat())
    except Exception:
        return False

def extrair(ev, cid, pais):
    pontos = mc.story_count_over_time(query=ev["palavra_chave"], start_date=ev["data_inicio"],
                                      end_date=ev["data_fim"], collection_ids=[cid])
    with open(caminho(ev, pais), "w", encoding="utf-8") as f:
        json.dump({
            "evento_referencia": ev["nome_evento"], "categoria": ev["categoria"],
            "pais_cobertura": pais, "collection_id_mediacloud": cid,
            "query_utilizada": ev["palavra_chave"],
            "data_extracao": datetime.datetime.now().isoformat(),
            "payload": [{"date": p["date"].isoformat(), "count": p["count"],
                         "total_count": p.get("total_count"), "ratio": p.get("ratio")} for p in pontos],
        }, f, ensure_ascii=False, indent=2)
    return len(pontos)

n, total = 0, len(eventos) * len(PAISES)
for ev in eventos:
    for cid, pais in PAISES.items():
        n += 1
        if arquivo_valido(ev, pais):
            continue
        print(f"[{n}/{total}] {ev['nome_evento']} [{pais}]...", end=" ")
        try:
            print(f"OK - {extrair(ev, cid, pais)} dias")
        except Exception as e:
            with open(LOG_FALHAS, "a") as log:
                log.write(f"{datetime.datetime.now().isoformat()} | {ev['nome_evento']} | {pais} | {e}\n")
            print(f"ERRO (registrado em falhas.log): {e}")
        time.sleep(5)
print("\nExtracao concluida. Rode a celula 4 para conferir.")

# ---------- CELULA 4: conferencia antes de levar para o Hop ----------
problemas, zerados = [], []
for ev in eventos:
    for cid, pais in PAISES.items():
        if not arquivo_valido(ev, pais):
            problemas.append(f"{ev['nome_evento']} [{pais}]: arquivo ausente ou divergente do CSV")
            continue
        d = json.load(open(caminho(ev, pais), encoding="utf-8"))
        if len(d["payload"]) != 91:
            problemas.append(f"{ev['nome_evento']} [{pais}]: {len(d['payload'])} dias (esperado 91)")
        if sum(x["count"] for x in d["payload"]) == 0:
            zerados.append(f"{ev['nome_evento']} [{pais}]")
arquivos = len(list(OUT_DIR.glob("*.json")))
print(f"Arquivos .json na pasta: {arquivos} (esperado 400)")
print(f"Problemas: {len(problemas)}")
for p in problemas: print("   ", p)
print(f"Evento x pais com zero materia na janela inteira: {len(zerados)}")
for z in zerados: print("   ", z)
