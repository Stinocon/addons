#!/command/with-contenv bashio
# Prepara le cartelle su /data prima che partano i servizi.
#
# Perché qui e non dentro i due servizi: se le creasse ciascuno per conto suo, l'ordine di
# avvio deciderebbe chi le crea, e un giorno in cui l'ordine cambia diventerebbe un guasto
# da capire. Meglio una sola volta, prima di tutti.
set -e

for cartella in /data/workspace /data/workspace/media /data/ollama /data/whisper; do
    mkdir -p "${cartella}"
done

bashio::log.info "Dati persistenti in /data (libreria, modelli, media scaricati)."

# Un avviso onesto invece di un guasto muto: il file dei cookie serve per i reel che
# richiedono l'accesso, e se il percorso è sbagliato lo si scopre solo al primo link.
if bashio::config.has_value 'file_cookie'; then
    file="/share/$(bashio::config 'file_cookie')"
    if [ -f "${file}" ]; then
        bashio::log.info "Cookie letti da ${file}."
    else
        bashio::log.warning "file_cookie punta a ${file}, che non esiste: i reel che richiedono l'accesso falliranno."
    fi
fi
