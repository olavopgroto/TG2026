# =====================================================================
# PASSO 1 - Valida os 40 titulos de artigo na Wikipedia EN.
# Roda LOCALMENTE (nao no Colab). Faz 1 chamada so.
# Uso:  python 01_validar_titulos.py
# =====================================================================
import csv, sys, requests

HEADERS = {"User-Agent": "TCC-Fatec-RioPreto/1.0 (olavopgroto15@gmail.com)"}
ARQ = "eventos_curados.csv"

eventos = list(csv.DictReader(open(ARQ, encoding="utf-8")))
titulos = [e["artigo_wikipedia"].replace("_", " ") for e in eventos]
print(f"Validando {len(titulos)} titulos...\n")

r = requests.get("https://en.wikipedia.org/w/api.php", headers=HEADERS, timeout=30,
                 params={"action": "query", "format": "json",
                         "titles": "|".join(titulos), "redirects": 1})

print("STATUS HTTP:", r.status_code)
if r.status_code != 200:
    print("\nA API bloqueou ou falhou. Primeiros 300 caracteres da resposta:")
    print(r.text[:300])
    sys.exit(1)

d = r.json()["query"]
redirects  = {x["from"]: x["to"] for x in d.get("redirects", [])}
normalized = {x["from"]: x["to"] for x in d.get("normalized", [])}
paginas    = {p["title"]: p for p in d["pages"].values()}

ok, redir, faltando = [], [], []
for ev, t in zip(eventos, titulos):
    alvo = redirects.get(normalized.get(t, t), normalized.get(t, t))
    pg = paginas.get(alvo)
    if pg is None or "missing" in pg:
        faltando.append((ev["nome_evento"], t))
    elif alvo != t:
        redir.append((ev["nome_evento"], t, alvo))
    else:
        ok.append(ev["nome_evento"])

print(f"\nOK ({len(ok)}) - titulo exato, nao precisa mexer")
for n in ok: print("  ", n)

print(f"\nREDIRECIONADOS ({len(redir)}) - trocar no CSV pelo nome da direita")
for n, a, b in redir: print(f"   {n}\n      {a}  ->  {b}")

print(f"\nNAO ENCONTRADOS ({len(faltando)}) - precisam correcao manual")
for n, t in faltando: print(f"   {n}: {t}")

if not redir and not faltando:
    print("\nTUDO CERTO. Pode seguir para o passo 2.")
