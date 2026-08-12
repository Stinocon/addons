# Changelog

## 1.0.3

**L'interfaccia parla anche inglese.** Il selettore sta in testata: la scelta viene
ricordata e alla prima apertura si parte dalla lingua del browser. Da lì scende una catena
di tre anelli — interfaccia, lingua della ricetta, sistema di misura — ciascuno con il
precedente come ripiego e ciascuno sovrascrivibile. Chi non tocca niente ottiene un insieme
coerente; chi cucina in una lingua e vive in un'altra può incrociarli.

**Il selettore della lingua non era collegato a niente.** Era disegnato nel pannello
*Opzioni* fin dalla 1.0.0, si poteva scegliere, e ogni estrazione usciva comunque in
italiano metrico. Un comando che non fa niente è peggio di un comando assente: insegna a
non fidarsi dell'interfaccia.

**A Whisper si diceva che ogni reel era italiano.** La lingua del parlato era fissata a
"it" e non era esposta da nessuna parte, quindi anche un reel inglese veniva trascritto
come se fosse italiano — parole italiane forzate su suoni inglesi, e da lì in poi tutto il
resto lavorava su quelle. Il difetto era invisibile, perché una ricetta plausibile il
modello la produce comunque. Ora la lingua la riconosce Whisper da sé, e resta forzabile
dalle *Opzioni* quando sbaglia.

**Trascinare un video perdeva le impostazioni.** Il caricamento di un file accettava solo
lingua e sistema: backend di trascrizione, modello e «usa solo la didascalia» venivano
scartati in silenzio. Ora le due strade prendono le stesse opzioni.

## 1.0.2

**Il modello non si scaricava più dopo un errore.** Alla prima installazione i 9 GB di
`qwen2.5:14b` sono arrivati interi e sono stati scartati dalla verifica dello sha256
(`digest mismatch`). Il pull si tentava una volta sola: dopo quel fallimento l'add-on
restava senza modello per sempre, e l'unico rimedio era riavviarlo a mano.

Ora ritenta **tre volte**, con attesa crescente. Tre e non infinite: se la causa è il disco
pieno, riprovare in eterno non la risolve. Per distinguere le due cause — un file troncato
per spazio esaurito dà lo stesso `digest mismatch` di una corruzione in transito — a ogni
fallimento il registro scrive lo spazio libero su `/data`.

**Il messaggio dell'interfaccia era sbagliato tre volte.** Consigliava
`ollama pull qwen2.5:7b-instruct`: un modello diverso da quello che l'add-on installa, e per
giunta quello scartato perché perde i gruppi di ingredienti e inventa le dosi. Diceva di
eseguire comandi in una shell che dentro Home Assistant non esiste. E non distingueva «nessun
modello» da «lo sto scaricando adesso», che è il caso normale della prima mezz'ora.

## 1.0.1

**L'interfaccia non partiva.** L'add-on si installava e si avviava, ma aprendolo Home
Assistant rispondeva «502 Bad Gateway».

Lo script di servizio passava `--ollama` dopo il sottocomando `serve`, ma è un'opzione
globale del programma e va prima: argparse usciva con codice 2, s6 riavviava il servizio
all'infinito, e l'Ingress non trovava nessuno in ascolto sulla porta 8500. Il server non è
mai partito nemmeno una volta — con un proxy davanti sembrava un problema di rete.

Il registro contribuiva all'equivoco: annunciava «Interfaccia pronta sull'Ingress» *prima*
di avviarla, quindi affermava a ogni riavvio una cosa che non era vera. Ora dice «Avvio
l'interfaccia» e non testimonia più su ciò che non ha visto.

Quella riga è un contratto fra due repository e non la controllava nessuno: ora è fissata da
`tests/test_cli.py` in Reel2Recipe.

## 1.0.0

Prima versione stabile. Le 0.1.x che l'hanno preceduta erano di collaudo e non sono più
disponibili: quanto avevano corretto è dentro questa.

- Interfaccia di Reel2Recipe servita tramite Ingress, nel pannello laterale.
- Ollama e Whisper girano dentro l'add-on: nessun servizio remoto, nessuna chiave API,
  nessun dato che lascia la macchina.
- Il modello LLM viene scaricato al primo avvio (`modello_llm`, `scarica_modello`) senza
  bloccare l'interfaccia, che nel frattempo dichiara di non essere pronta. Il modello di
  trascrizione (~1,5 GB) si scarica anch'esso all'avvio, e non alla prima ricetta: prima la
  barra si fermava su «Trascrizione del parlato» per minuti senza spiegazione.
- Libreria, media e modelli su `/data`; modelli e media esclusi dai backup.
- `file_cookie` per i reel che richiedono l'accesso, letto da `/share` in sola lettura. Si
  lavora su una copia privata e temporanea: yt-dlp riscrive quel file a fine scaricamento,
  ma `/share` è montato in sola lettura, e senza la copia un download riuscito falliva
  all'ultimo passo. La copia contiene credenziali di sessione, quindi nasce con permessi
  ristretti e nome imprevedibile, e viene cancellata alla fine.
- I passi del procedimento escono senza numerazione: Mela numera le righe da sé, e
  aggiungerla produceva «1 1. Frullare il tofu».
- Solo `amd64`: l'inferenza gira su CPU e serve una macchina con 16 GB di RAM.
