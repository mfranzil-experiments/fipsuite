#!/bin/bash

function getdata() {
    COMITATO=$1
    GARA=$2

    # Pad the GARA variable to 6 digits if less
    while [[ ${#GARA} -lt 6 ]]; do
        GARA="0$GARA"
    done

    DATA=$(curl -s 'https://www.fip.it/ajax-risultati-get-dettaglio-partita.aspx' -X POST --data-raw "com=${COMITATO}&IDGara=${GARA}" |
        grep -B 1000 "visible-xs" | # Seleziona il segmento di pagina desktop, visto che è ripetuto
        grep -v "visible-xs" |
        grep -A 1000 "Titolo" |
        sed "s/<\!-*.*-*>//g" |        # Rimuove i commenti HTML
        sed "s/&deg;//g" |             # Sostituisce &deg; con °
        lynx -stdin -dump -width 200 | # Trasforma in formato preview
        aha |                          # Re-parse in HTML
        grep -A 1000 "<pre>" |         # Seleziona solo parte preformattata
        grep -B 1000 "</pre>" |
        grep -v "pre" |
        sed -E "s/'//g" |   # Rimozione apici che creano problemi al parsing
        sed -E "s/^ *//g" | # Rimozione righe completamente vuote
        grep -vE "^$" |
        sed -E "s/^( |\t)//g" |                                             # Rimuove gli spazi e i tab a inizio riga
        sed -E "s/ *\[.*\] *//g" |                                          # Rimozioni tag delle immagini delle società
        sed -E "1s/^/Campionato: /" |                                       # Aggiunta informazione "Campionato" in testa alla prima riga
        sed -E "2s/^.*$//g" |                                               # Cancello completamente la seconda riga
        sed -E "3s/^ *([0-9]+) *.*$/\1/g" |                                 # Prende il numero partita
        sed -E "3s/^0*/Gara: /" |                                           # Aggiunta informazione "Gara" in testa alla terza riga
        sed -E "4s/^ *([0-9]+\/[0-9]+\/[0-9]+ *- *[0-9]+:[0-9]+).*$/\1/g" | # Prende la data partita
        sed -E "4s/^/Data_Ora: /" |                                         # Aggiunta informazione "Data ora" in testa alla terza riga
        sed -E "4s/ Arbitri non ancora designati/\narbitri_designati: false/g" |
        sed -E "4s/ . provvedimento disciplinar./\nHas_Provvedimenti: true/g" | # Se provvedimento, si -> 1
        sed "s/Designazione in attesa di conferma.//g" |                        #  Rimozione messaggi inutili di attesa designazione
        sed -E "s/^ *//g" |                                                     # Rimozione righe completamente vuote (si ancora)
        grep -vE "^$" |
        #grep -vE "([a-zA-Z] *)* [0-9]{,3} [0-9]{,3} ([a-zA-Z] *)*" | # Rimozione informazioni duplicate sul punt.
        #sed -E "s/^ *//g" |                                          # Rimozione righe completamente vuote (si ancora)
        #grep -vE "^$" |
        sed -E "s/:(\t| )*/:\t/" |
        sed -E "s/^Provvedimenti:( |\t)*/\"provvedimenti\":[/" |
        #sed -E "s/^soc. (.*?):( |\t)*(.*?)/\"\1 \3\",/g" |
        #sed -E "s/^(.*):( |\t)(.*)$/\"\L\1\E\": \"\3\",/" |
        sed -E '$s/,$//')
    TAB=$'\t'
    __tmp=$(echo "${DATA}" |
        sed -E "s/^soc. (.*?):( |\t)*(.*?)/\"\1 \3\",/g" |
        sed -E "s/^(.*):( |\t)(.*)$/\"\L\1\E\": \"\3\",/")

    if echo "$__tmp" | grep -q "provvedimenti"; then
        __tmp=$(echo "${__tmp}" | grep -B 1000 "\"provvedimenti\":" | grep -v "\"provvedimenti\": ")
    fi

    provv=$(
        echo "$DATA" |
            grep "provvedimenti" -A 100 |
            grep -v "\"provvedimenti\":" |
            tr "\n" " " |
            sed -E "s/( |${TAB})+/ /g" |
            sed -E "s/[^\"]soc\./\", \"soc\./g"
    )

    DATA="$__tmp\"$provv\""

    DATA="{$DATA"

    if [[ ! $DATA != *rovvediment* ]]; then
        DATA="$DATA]}"
    else
        DATA="$DATA}"
    fi

    if [[ "$DATA" != "{\"\"}" ]]; then
        echo "$DATA" |
            sed "s/,\"\"//g" |
            grep -E "^(\"|\}|\{)" |
            iconv -f utf-8 -t utf-8 --byte-subst="" | # | tr '\n' ' '
            jq ". +  {\"comitato\": \"${COMITATO}\"}"
    fi

    # jq

}

function getdata_list() {
    # Parameters: $1 = comitato [$2 = inizio $3 = fine]
    if [[ -z "$2" ]]; then
        inizio=1
    else
        inizio=$2
    fi

    if [[ -z "$3" ]]; then
        fine=10000
    else
        fine=$3
    fi


    echo "["
    for ((i = inizio; i <= fine; i++)); do
        RESULT=$(getdata "$1" "$i")
        echo "$RESULT" | jq
        
        if [[ $i != "$fine" ]]; then
            echo ","
        fi

        sleep $((RANDOM % ((i / 10) + 1) + 1 ))
    done
    echo "]"
}

function terminate_squarebracket() {
    echo "{}]"
    exit 0
}

function getdata_find() {
    # Parameters: $1 = comitato $2 = search string
    n=0

    trap terminate_squarebracket SIGINT SIGTERM

    search="$(echo "$2" | tr '[:upper:]' '[:lower:]')"
    echo "["
    while true; do
        __DATA=$(getdata "$1" "$n")
        lower_data="$(echo "$__DATA" | tr '[:upper:]' '[:lower:]')"
        if [[ "$lower_data" == *"$search"* ]]; then
            echo "[INFO] Match $n@$1" >&2
            echo "$__DATA"
            echo ","
            # echo "$__DATA" | jq
        fi
        n=$((n + 1))

    done
    echo "]"
}

function getdata_given() {
    RESULT=$(getdata "$@")
    echo "$RESULT" | jq
}
