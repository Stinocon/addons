# Reel2Recipe — add-on per Home Assistant

Estrae ricette dai reel di cucina e le rende utilizzabili: le struttura, ne normalizza le
quantità, le archivia in una libreria ricercabile e le esporta in formato **Mela**.

Il problema che risolve non è "estrarre una ricetta" ma **ritrovarla**: chi salva ricette su
Instagram poi non le ritrova più.

Codice sorgente e documentazione completa: **[Stinocon/Reel2Recipe](https://github.com/Stinocon/Reel2Recipe)**.

## Cosa gira dentro l'add-on

Tutto. La trascrizione usa **Whisper** in locale, la strutturazione un **LLM locale via
Ollama**, entrambi dentro questo container. Nessuna chiave API, nessun abbonamento, nessun
dato che lascia la macchina — ed è un vincolo di progetto, non una caratteristica di questa
versione: il prodotto deve continuare a funzionare anche se si smette di pagare qualsiasi
cosa.

Il corollario è che il lavoro pesante lo fa la CPU del tuo server.

## Requisiti

| | |
|---|---|
| Architettura | **amd64 soltanto** — un miniPC o un NUC, non un Raspberry |
| RAM | **16 GB** consigliati: il modello predefinito ne occupa circa 9 quando è caricato |
| Disco | **~15 GB**: 1,5 GB di immagine, ~9 GB per il modello LLM, ~1,5 GB per Whisper |
| Tempi | Alcuni minuti per ricetta su CPU. È un lavoro da lanciare e lasciar fare |

Se la macchina è più modesta, in `modello_llm` si può mettere `qwen2.5:7b-instruct`: dimezza
memoria e tempi, ma **perde i gruppi di ingredienti** ("per la salsa", "per la base") e
tende a completare le dosi mancanti invece di dichiararle. Il modello grande resta il
predefinito per questa ragione.

## Installazione

1. In Home Assistant: **Impostazioni → Add-on → Store**, menu in alto a destra,
   **Repository**, e aggiungi:

   ```
   https://github.com/Stinocon/addons
   ```

2. Installa **Reel2Recipe** e avvialo.
3. **Il primo avvio scarica circa 10 GB**: il modello di linguaggio e quello di trascrizione.
   L'interfaccia è già raggiungibile nel frattempo e mostra "LLM non pronto" finché non ha
   finito; il registro dell'add-on riporta un avanzamento ogni minuto. Si scaricano una volta
   sola e restano su `/data`, quindi gli aggiornamenti dell'add-on non li ripagano.
4. Apri il pannello dalla barra laterale.

## Opzioni

| opzione | predefinito | cosa fa |
|---------|-------------|---------|
| `modello_llm` | `qwen2.5:14b` | Il modello Ollama che struttura la ricetta. Scaricato al primo avvio se manca |
| `scarica_modello` | `true` | Disattivalo se preferisci gestire i modelli a mano |
| `file_cookie` | *(vuoto)* | File di cookie in formato Netscape dentro `/share`. Vanno bene sia `cookies.txt` sia `/share/cookies.txt`. Il file non viene mai modificato: se ne usa una copia |
| `log_level` | `info` | Verbosità del registro |

## Come si usa

Due strade, e non sono equivalenti sul piano legale:

- **Carichi un file** che hai già sul dispositivo (trascina-e-rilascia sulla pagina),
  incollando la didascalia. È la strada senza attriti.
- **Incolli il link** del reel: l'add-on lo scarica. Scaricare un reel viola i Termini d'Uso
  di Instagram — è la ragione per cui questo strumento è **locale e per uso personale**, e
  perché l'alternativa senza download esiste sempre. Vedi
  [docs/legale.md](https://github.com/Stinocon/Reel2Recipe/blob/main/docs/legale.md).

Instagram richiede l'accesso per buona parte dei contenuti. Qui dentro non c'è un browser da
cui prendere i cookie, quindi la via è esportarli altrove in formato Netscape, metterli in
`/share` e indicarli in `file_cookie` — per esempio `cookies-instagram.txt`.

Il risultato non è un file buttato in una cartella: la ricetta entra in una libreria con
ricerca full-text, si corregge a mano dove serve, e si esporta in `.melarecipe`, Markdown o
PDF.

## Quello che non fa, e va saputo prima

- **Le quantità non le converte il modello, le converte il codice** con tabelle di densità
  che hanno una fonte dichiarata. Dove una densità non è nota, la conversione non si fa: si
  conserva il volume e si dichiara la lacuna. Un peso sbagliato di cui non sai che è
  sbagliato, in cucina, fa danni.
- **Non inventa.** Quantità o passaggi non deducibili dal materiale restano buchi
  dichiarati. Una ricetta incompleta ma onesta è utilizzabile; una completata a caso no.
- **La traduzione italiano → inglese è il punto debole.** Su didascalie italiane lunghe il
  modello traduce il titolo e resta ancorato all'italiano nell'elenco. È un limite del
  modello locale, non della conversione, che resta deterministica in entrambe le direzioni.
- **Non crea entità in Home Assistant.** È un'applicazione che vive nel pannello laterale,
  non un'integrazione: non ci sono sensori, servizi o automazioni.

## Dati e backup

Tutto sta su `/data`, che sopravvive agli aggiornamenti:

```
/data/workspace/ricette.db     la libreria
/data/workspace/media/         i reel scaricati
/data/ollama/                  i modelli LLM
/data/whisper/                 i modelli di trascrizione
```

Modelli e media sono **esclusi dai backup** di Home Assistant: sono una decina di GB
riscaricabili, e un backup che li contenesse sarebbe ingestibile. La libreria delle ricette,
che è l'unica cosa non riproducibile, è invece dentro.

Il materiale scaricato è di terzi: resta qui e non si ridistribuisce.

## Segnalazioni

I problemi di **installazione, configurazione o avvio dell'add-on** vanno
[qui](https://github.com/Stinocon/addons/issues). Tutto ciò che riguarda la ricetta —
trascrizione, ingredienti, conversioni, esportazioni — va invece su
[Stinocon/Reel2Recipe](https://github.com/Stinocon/Reel2Recipe/issues), dove sta il codice.

## Licenza

MIT: questo add-on sotto la [`LICENSE`](../LICENSE) del repository, l'applicazione sotto
[quella di Reel2Recipe](https://github.com/Stinocon/Reel2Recipe/blob/main/LICENSE). Le
attribuzioni delle dipendenze stanno nel
[NOTICE.md di Reel2Recipe](https://github.com/Stinocon/Reel2Recipe/blob/main/NOTICE.md); la
provenienza di quanto sta in questo repository nel [`NOTICE.md`](../NOTICE.md) qui accanto.
