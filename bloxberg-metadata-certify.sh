#!/usr/bin/env bash
#
# Description : Ce script génère un fichier de métadonnées pour un jeu de données puis, en utilisant
# l'API bloxberg, il certifie ce fichier de métadonnées sur la blockchain bloxberg
# et télécharge le certificat correspondant.
# Usage : ./metadata-bloxberg-certify.sh CLÉ_API_BLOXBERG WALLET_BLOXBERG JEU_DE_DONNÉES
# Référence API bloxberg : https://certify.bloxberg.org/docs
# Licence : GPL-3+ (https://www.gnu.org/licenses/gpl-3.0.txt)
# Auteur : Cédric Goby
# Versioning : https://forgemia.inra.fr/blockchain-esr/bloxberg-certify-metadata

# Vérifier si la clef API, l'adresse du wallet bloxberg et le chemin vers le jeu de données
# ont été fournis au script.
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
  echo "Vous n'avez pas fourni votre clé API bloxberg, l'adresse de votre wallet bloxberg"
  echo "ou le chemin vers votre jeu de données"
  echo "Usage : ./metadata-bloxberg-certify.sh CLÉ_API_BLOXBERG WALLET_BLOXBERG JEU_DE_DONNÉES"
  exit 1  # Quitter le script avec un code d'erreur
fi

# --------------------------------------------------------------------------------------------
# ETAPE 1
# --------------------------------------------------------------------------------------------
# Création du fichier de métadonnées "metadata.json" pour un jeu de données. 
# Le fichier "metadata.json" est au format JSON-LD. Les métadonnées sont décrites en utilisant les standards DUBLIN CORE et PREMIS.
# --------------------------------------------------------------------------------------------

# Début du fichier "metadata.json".
cat >metadata.json << EOF
{
  "@context": {
    "dc": "http://purl.org/dc/terms/",
    "premis": "http://www.loc.gov/premis/rdf/v1#"
  },
  "@type": "text",
  "dc:creator": "https://orcid.org/0009-0004-8417-3677",
  "dc:language": "fr",
  "dc:format": "text/markdown",
  "dc:title": "Revue de presse sur la sécurité informatique",
  "dc:subject": "http://id.loc.gov/authorities/subjects/sh90001862",
  "dc:date": "$(date -u +"%Y-%m-%dT%H:%M:%S.%6N")",
  "dc:description": "Cette revue de presse généraliste mensuelle a pour but de sensibiliser le public aux problématiques de la sécurité informatique.",
  "dc:publisher": [
    "http://viaf.org/viaf/3881157583857733970006",
    "http://viaf.org/viaf/314926296"
  ],
  "dc:rights":"http://spdx.org/licenses/CC-BY-NC-SA-4.0.json",
  "dc:identifier": [
EOF
# On insert l'URI pérenne et la SOMME DE CONTRÔLE de chaque fichier markdown dans le fichier "metadata.json".
for _file in $(ls -t $3/*.md); do
cat >>metadata.json << EOF
    {
      "@value": "https://gitlab.com/CedricGoby/newsletter-securite-informatique/-/blob/master/$(basename $_file)",
      "@type": "http://purl.org/dc/terms/URI",
      "premis:hasMessageDigest": {
        "@type": "premis:MessageDigest",
        "premis:messageDigestAlgorithm": "SHA-256",
        "premis:messageDigest": "$(sha256sum "$_file" | awk '{print $1}')"
      }
    },
EOF
done
# Suppression de la dernière ligne du fichier "metadata.json" pour retirer "},"
sed -i '$d' metadata.json
# Fin du fichier "metadata.json".
cat >>metadata.json << EOF
     }
   ]
 }
EOF
# TODO : Générer un fichier README.txt (lisible par les humains) à partir du fichier de métadonnées JSON.

# --------------------------------------------------------------------------------------------
# ETAPE 2
# --------------------------------------------------------------------------------------------
# Certification du fichier "metadata.json" dans la blockchain bloxberg en utilisant l'API bloxberg.
# --------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------
# Création d'un fichier contenant la valeur de la clé "metadataJson" attendue par l'API bloxberg.
# La valeur est au format JSON et utilise le standard Dublin Core.
# --------------------------------------------------------------------------------------------
# Nom du fichier contenant la valeur de la clé "metadataJson".
_metadataJson="bloxberg_metadataJson.json"

# Création du fichier.
cat >$_metadataJson << EOF
{
  "@context": {
    "dc": "http://purl.org/dc/terms/"
  },
  "@type": "text",
  "dc:creator": "https://orcid.org/0009-0004-8417-3677",
  "dc:language": "fr",
  "dc:format": "application/json",
  "dc:title": "Métadonnées des revues de presse sur la sécurité informatique",
  "dc:subject": "http://id.loc.gov/authorities/subjects/sh90001862",
  "dc:date": "$(date -u "+%Y-%m-%dT%H:%M:%S.%NZ" | sed 's/.\{6\}$//' | sed 's/$/Z/')",
  "dc:description": "Informations sur les fichiers markdown des revues de presse sur la sécurité informatique",
  "dc:publisher": [
    "http://viaf.org/viaf/3881157583857733970006",
    "http://viaf.org/viaf/314926296"
  ],
  "dc:rights":"http://spdx.org/licenses/CC-BY-NC-SA-4.0.json",
  "dc:identifier": {
    "@value": "https://gitlab.com/CedricGoby/newsletter-securite-informatique/-/blob/master/$_metadata_file",
    "@type": "http://purl.org/dc/terms/URI"
    }
}
EOF

# --------------------------------------------------------------------------------------------
# Appel à l'API bloxberg pour certifier le fichier de métadonnées "metadata.json" sur la blockchain bloxberg.
# --------------------------------------------------------------------------------------------
# Clé API fournie par bloxberg (Paramètre positionnel 1).
_api_key="$1"
# Adresse du wallet bloxberg (Paramètre positionnel 2).
_public_key="$2"
# SOMME DE CONTRÔLE du fichier de métadonnées "metadata.json" (crid = Content Reference IDentifier).
_crid=$(sha256sum "$_metadata_file" | awk '{print $1}')
# A partir du fichier contenant la valeur de la clé "metadataJson" on formate la valeur de la clé pour l'API.
_metadataJson=$(cat $_metadataJson | jq -c . | sed -e 's/"/\\"/g')
# Nom du fichier contenant la réponse JSON de l'API.
_json_response=bloxberg_json_response.json
## Création du fichier contenant la réponse JSON de l'API.
touch $_json_response
# Nom du fichier de logs (Erreurs).
_error_log=error.log

# --------------------------------------------------------------------------------------------
# Envoi de la requête CURL, écriture de la réponse JSON de l'API dans un fichier
# et récupération du code de réponse HTTP.
# --------------------------------------------------------------------------------------------
_http_request=$(curl --write-out '%{http_code}' -X 'POST' \
  'https://certify.bloxberg.org/createBloxbergCertificate' \
  -H 'accept: application/json' \
  -H 'api_key: '"$_api_key"'' \
  -H 'Content-Type: application/json' \
  -d '{
  "publicKey": "'"$_public_key"'",
  "crid": [
     "'"$_crid"'"
],
  "cridType": "sha2-256",
  "enableIPFS": false,
  "metadataJson": "'"$_metadataJson"'"
}' --output $_json_response --silent)

# --------------------------------------------------------------------------------------------
# Vérification du code de réponse HTTP (Code 200 attendu).
# --------------------------------------------------------------------------------------------
if [ ${_http_request} -ne 200 ] ; then
    echo "$(date) - HTTP error : $_http_request" | tee -a $_error_log
    exit 1  # Quitter le script avec un code d'erreur
fi

# --------------------------------------------------------------------------------------------
# Vérification de la validité de la réponse JSON.
# --------------------------------------------------------------------------------------------
# Début de la séquence JSON attendue.
_expected_json_response='[{"@context":["https://www.w3.org/2018/credentials/v1",'
# Formatage de la réponse JSON sur une ligne.
_one_line_json_response=$(jq -c . $_json_response)
# Erreur si la réponse ne commence pas par la séquence attendue, écriture de la (mauvaise) réponse
# dans le fichier de log.
if [[ ! "$_one_line_json_response" =~ ^"$_expected_json_response" ]]; then
    echo "$(date) - JSON error : $(cat $_json_response)" | tee -a $_error_log
    exit 1  # Quitter le script avec un code d'erreur
fi

# FIXME : Délai de validation du bloc ?
sleep 900

# --------------------------------------------------------------------------------------------
# ETAPE 3
# --------------------------------------------------------------------------------------------
# Appel à l'API bloxberg pour télécharger le certificat du fichier "metadata.json" au format PDF.
# Le contenu JSON qui doit être envoyé à l'API est la réponse JSON obtenue à l'issue de la certification (ETAPE 2)
# --------------------------------------------------------------------------------------------
# Nom du fichier ZIP téléchargé contenant le certificat au format PDF.
_bloxberg_certificate=bloxberg_certificate-crid-$_crid.zip

# --------------------------------------------------------------------------------------------
# Envoi de la requête CURL, téléchargement du fichier ZIP et récupération du code de réponse HTTP.
# --------------------------------------------------------------------------------------------
_http_request=$(curl --write-out '%{http_code}' -X 'POST' \
  'https://certify.bloxberg.org/generatePDF' \
  -H 'accept: application/json' \
  -H 'api_key: '"$_api_key"'' \
  -H 'Content-Type: application/json' \
  -d ''"$(cat $_json_response)"'' --output $_bloxberg_certificate --silent)

# --------------------------------------------------------------------------------------------
# Vérification du code de réponse HTTP (Code 200 attendu).
# --------------------------------------------------------------------------------------------
if [ ${_http_request} -ne 200 ] ; then
    echo "$(date) - HTTP error : $_http_request" | tee -a $_error_log
    exit 1
fi

# TODO : Vérifier l'intégrité du fichier téléchargé.
# TODO : Extraire l'archive.

# --------------------------------------------------------------------------------------------
# ETAPE 4
# --------------------------------------------------------------------------------------------
# Appel à l'API bloxberg pour télécharger le certificat du fichier "metadata.json" au format PDF.
# Le contenu JSON qui doit être envoyé à l'API est la réponse JSON obtenue à l'issue de la certification (ETAPE 2)
# --------------------------------------------------------------------------------------------
#mv -f metadata.json $3/metadata.json

# Mise à jour du dépôt Gitlab avec le nouveau fichier "metadata.json"
#cd $3
#git add metadata.json
#git commit -m "Ajout du fichier de métadonnées"
#git push

exit 0  # Fin du script.