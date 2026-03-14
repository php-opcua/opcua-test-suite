# Changelog

## v1.1.0 — 2026-03-14

### GitHub Action e CI

- **action.yml**: Corretto il bug che usava `github.action_repository` (vuoto nei
  composite action) con fallback su `github.repository`, causando il pull
  dell'immagine Docker sbagliata (`opcua-php` invece di `opcua-test-server-suite`).
  Il nome dell'immagine GHCR è ora hardcoded correttamente.

- **action.yml**: Aggiunto step di login a GHCR con `github.token` per supportare
  immagini private.

- **action.yml**: I certificati vengono ora letti direttamente dal bind mount
  (`./certs`) invece di estrarli da un Docker volume tramite container temporaneo,
  eliminando i problemi di nomi di volume non trovati in CI.

- **docker-compose.ci.yml**: Cambiato da Docker volume (`certs-volume`) a bind mount
  (`./certs`), allineato con `docker-compose.yml`. I certificati sono accessibili
  direttamente sul filesystem host senza estrazione.

### Certificati e PKI

- **generate-certs.sh**: Aggiunta generazione CRL (Certificate Revocation List) per la CA.
  node-opcua richiede una CRL per verificare lo stato di revoca dei certificati client.
  Senza CRL, il server rifiuta tutte le connessioni sicure con
  `BadCertificateRevocationUnknown (0x801b0000)`, anche con `autoAcceptCerts: true`.

- **index.js**: Ristrutturata la gestione PKI con `populatePki()`.
  I certificati CA e la CRL vengono ora copiati nelle directory PKI **prima** di
  `certificateManager.initialize()`, perché node-opcua indicizza i file CRL
  durante l'inizializzazione e non li rileva se aggiunti dopo.

- **index.js**: Aggiunto `userCertificateManager` per l'autenticazione X509.
  node-opcua usa due certificate manager separati: uno per il livello trasporto
  (OPN/SecureChannel) e uno per i token utente (ActivateSession). Senza il
  secondo, l'autenticazione con certificato X509 fallisce con
  `BadIdentityTokenRejected (0x80210000)`.

- **docker-compose.yml**: Cambiato da Docker volume (`certs-volume`) a bind mount
  (`./certs`) per rendere i certificati generati accessibili dall'host, necessario
  per i test di integrazione che referenziano direttamente i file certificato.

### Address Space

- **events-alarms.js**: Corretta la creazione degli allarmi.
  - `alarmsFolder` registrato come event source sul server object con
    `HasEventSource` reference e `setEventNotifier(1)`, necessario perché
    node-opcua richiede che il `conditionSource` sia un event source valido.
  - Cambiato `conditionSource` da `alarmSource` (variabile) a `alarmsFolder`
    (folder) per tutti e 3 gli allarmi.
  - Corretta la chiamata `instantiateOffNormalAlarm`: rimosso il primo argomento
    stringa `"OffNormalAlarmType"` (il metodo di namespace lo include già) e
    passati `nodeId` invece di oggetti per `inputNode` e `normalState`.

- **historical.js**: Aggiunte chiamate `setValueFromSource()` nel `setInterval`.
  L'aggiornamento delle variabili locali non basta: node-opcua registra i dati
  storici solo quando il valore viene impostato tramite `setValueFromSource()`,
  che triggera il meccanismo interno di historical data recording.

- **access-control.js**: Aggiunti `rolePermissions` alle variabili OperatorLevel
  (`Setpoint`, `MotorSpeed`, `ProcessEnabled`). Senza permessi per ruolo,
  node-opcua permette la scrittura a qualsiasi utente autenticato, impedendo
  di testare le restrizioni di accesso basate su ruoli.

- **data-types.js**: Cambiato il valore di `Int64Value` da `[0, -1000000]` a
  `[0, 1000000]`. Il formato `[high, low]` di node-opcua per Int64 non supporta
  valori negativi nella parte `low`, causando un crash del server con
  `ERR_OUT_OF_RANGE` durante la serializzazione binaria.
