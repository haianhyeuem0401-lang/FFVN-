# FF Cache Manager — Comment l'app se protège du crack

## Vue d'ensemble

L'idée centrale : **les protections critiques vivent côté SERVEUR**, pas seulement
dans l'app. Même si quelqu'un patche l'app sur son appareil, il ne peut rien
obtenir sans casser aussi le serveur (qui est sous contrôle du propriétaire).

## Les 10 couches de protection

1. **Licence obligatoire serveur**
   Sans clé valide + session signée + appareil lié, aucune fonction ne marche.
   Le serveur vérifie la clé, le `installation_id` (device binding), le plan,
   et la vérification du canal Telegram.

2. **Intégrité du binaire (client → serveur)**
   L'app calcule les hashes SHA-256 de ses sections `__text` / `__cstring`
   et des 2 tranches du framework protégé `CoreTelemetry` (texte + exports +
   toutes les sections), puis les envoie au serveur qui les compare au
   **manifeste de release signé**. Un binaire modifié → `INTEGRITY_FAILED`.

3. **Réponses serveur signées (RSA-PSS-SHA256)**
   Chaque réponse du serveur est signée. L'app vérifie la signature avec la
   clé publique embarquée avant d'utiliser la moindre donnée. Un faux serveur
   ne peut pas répondre.

4. **Chiffrement binaire-lié (FFC1)**
   Les payloads (profils BODY/DRAG/NECK, shaders HOLOGRAM GUN / SKIN HOLO…)
   sont chiffrés par le serveur avec une clé dérivée des hashes des sections
   EN MÉMOIRE du binaire + token de session + token de feature + nonce.
   Si le binaire est patché, le déchiffrement échoue → aucun payload.

5. **Grants à usage unique**
   `/feature/authorize` délivre un token de feature à usage unique (un seul
   téléchargement possible par autorisation).

6. **Anti-débogueur**
   `PT_DENY_ATTACH` + détection `P_TRACED` (sysctl) → le debugger est tué.

7. **Détection d'instrumentation**
   - Frida / Cycript / Substrate / Substitute / ElleKit / libhooker / fishhook
     (par nom d'image chargée)
   - `DYLD_INSERT_LIBRARIES`
   - Dylibs inattendues dans le bundle (seul `CoreTelemetry.framework` accepté)

8. **Détection de hooks sur les fonctions critiques** (nouveau)
   `SecKeyVerifySignature`, `CC_SHA256`, `sandbox_extension_consume`…
   L'adresse résolue doit rester dans les bibliothèques système Apple
   (`/usr/lib`, `/System/Library`). Un hook (fishhook/Substitute) fait pointer
   vers une dylib injectée → verrouillage immédiat.

9. **Vérification RAM vs disque**
   Le code en mémoire (`__text`/`__cstring`) doit être identique au binaire
   signé sur disque (sur iOS 17+ : obligatoire, sinon échec).

10. **TLS Certificate Pinning** (nouveau)
    L'app n'accepte QUE le certificat du serveur d'activation et sa chaîne
    Let's Encrypt (leaf + intermédiaire + racines, épinglés par SHA-256).
    Un MITM (SSL Kill Switch, proxy Burp/Charles, CA personnalisée) est
    refusé au handshake → impossible de sniffer tokens/keys.

11. **Bonus**
    - Icônes de l'app vérifiées par hash (anti re-branding)
    - Payloads sensibles jamais embarqués dans l'IPA (téléchargés seulement
      après autorisation + intégrité)
    - Proxy système ignoré (`connectionProxyDictionary` vide)
    - Chaîne de certificats épinglée avec les racines valides jusqu'à 2035
      (le renouvellement Let's Encrypt automatique ne casse pas l'app)

## Ce qui se passe si on crack

| Attaque | Conséquence |
|---|---|
| Modifier le binaire (hex-edit) | `INTEGRITY_FAILED` serveur — rejet |
| Dumper/pacher l'app | hashes RAM/disque + manifeste serveur — rejet |
| Hooker les vérifications | détection de hooks + verrouillage |
| MITM / SSL Kill Switch | TLS pinning — connexion refusée |
| Réponses forgées | signature RSA — rejet |
| Voler un payload | FFC1 indéchiffrable sans le binaire authentique |
| Réutiliser un token | grants à usage unique — refus |

## Limites honnêtes

Aucune app n'est "uncrackable" à 100%. Ce design rend le crack
**non rentable** : il faut casser à la fois l'app ET le serveur, et le
serveur (manifeste signé, clés, plans de licence) reste sous contrôle du
propriétaire. C'est le même modèle de sécurité que les licences serveur des
produits commerciaux.
