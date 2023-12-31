#!/usr/bin/env bash
#
# Description : Ce script génère un fichier de métadonnées pour un jeu de données puis, en utilisant
# l'API bloxberg, il certifie ce fichier de métadonnées sur la blockchain bloxberg
# et télécharge le certificat au format PDF.
# Usage : ./metadata-bloxberg-certify.sh CLÉ_API_BLOXBERG WALLET_BLOXBERG REPERTOIRE_JEU_DE_DONNÉES
# Référence API bloxberg : https://certify.bloxberg.org/docs
# Licence : GPL-3+ (https://www.gnu.org/licenses/gpl-3.0.txt)
# Auteur : Cédric Goby
# Versioning : https://forgemia.inra.fr/blockchain-esr/bloxberg-certify-metadata

# Vérifier si la clef API, l'adresse du wallet bloxberg et le chemin vers le jeu de données
# ont été fournis au script.
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
  echo "Vous n'avez pas fourni votre clé API bloxberg, l'adresse de votre wallet bloxberg"
  echo "ou le chemin vers votre jeu de données"
  echo "Usage : ./metadata-bloxberg-certify.sh CLÉ_API_BLOXBERG WALLET_BLOXBERG REPERTOIRE_JEU_DE_DONNÉES"
  exit 1  # Quitter le script avec un code d'erreur
fi

# --------------------------------------------------------------------------------------------
# ETAPE 1 - Création d'un fichier de métadonnées "metadata.json" pour un jeu de données.
# --------------------------------------------------------------------------------------------
# Le jeu de données est contenu dans un répertoire connecté à un dépôt Gitlab.
# Le fichier "metadata.json" est au format JSON-LD, les métadonnées sont décrites
# en utilisant les standards DUBLIN CORE et PREMIS.
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
# On insert l'URI pérenne et la SOMME DE CONTRÔLE de chaque fichier markdown du jeu de données dans le fichier "metadata.json".
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
# ETAPE 2 - Certification du fichier "metadata.json" dans la blockchain bloxberg en utilisant l'API bloxberg.
# --------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------
# Création d'un fichier contenant la valeur de la clé "metadataJson" attendue par l'API bloxberg.
# La valeur est au format JSON et utilise le standard Dublin Core.
# --------------------------------------------------------------------------------------------
# Nom du fichier contenant la valeur de la clé "metadataJson".
_metadataJson=bloxberg_metadataJson.json

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
# Appel de l'API bloxberg pour certifier le fichier de métadonnées "metadata.json" sur la blockchain bloxberg.
# --------------------------------------------------------------------------------------------
# Clé API fournie par bloxberg (Paramètre positionnel 1).
_api_key=$1
# Adresse du wallet bloxberg (Paramètre positionnel 2).
_public_key=$2
# SOMME DE CONTRÔLE du fichier de métadonnées "metadata.json" (crid = "Cryptographic Identifier").
_crid=$(sha256sum $_metadata_file | awk '{print $1}')
# A partir du fichier contenant la valeur de la clé "metadataJson" on formate la valeur de cette clé pour l'API.
_metadataJson=$(cat $_metadataJson | jq -c . | sed -e 's/"/\\"/g')
# Nom du fichier contenant la réponse JSON de l'API.
_json_response=bloxberg_json_response.json
# Nom du fichier de logs (Erreurs).
_error_log=error.log

# --------------------------------------------------------------------------------------------
# Requête CURL vers l'API bloxberg (/createBloxbergCertificate),
# vérification du code de réponse HTTP et écriture de la réponse JSON dans un fichier.
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
# ETAPE 3 - Téléchargement du certificat bloxberg au format PDF pour le fichier "metadata.json"
# --------------------------------------------------------------------------------------------
# Le certificat bloxberg au format PDF contient les informations suivantes :
# - Cryptographic Identifier : Somme de contrôle du fichier "metadata.json".
# - Transaction ID : Identifiant de la transaction sur la blockchain bloxberg.
# - Timestamp : Horodatage de la transaction.
# - Merkle Root : Somme de contrôle de toutes les sommes de contrôle, de l'ensemble des transactions qui font partie d'un bloc dans un réseau blockchain.
# --------------------------------------------------------------------------------------------
# Nom du fichier ZIP téléchargé contenant le certificat au format PDF.
_bloxberg_certificate=bloxberg_certificate-crid-$_crid.zip

# --------------------------------------------------------------------------------------------
# Requête CURL vers l'API bloxberg (/generatePDF),
# vérification du code de réponse HTTP et téléchargement du fichier ZIP.
# Le contenu JSON qui doit être envoyé à l'API est la réponse JSON obtenue à l'issue de la certification (ETAPE 2)
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
    exit 1  # Quitter le script avec un code d'erreur
fi

# --------------------------------------------------------------------------------------------
# Extraction du certificat au format PDF contenu dans le fichier ZIP.
# --------------------------------------------------------------------------------------------
# Récupération du nom du fichier PDF contenu dans le fichier ZIP.
_bloxberg_certificate_PDF=$(unzip -l $_bloxberg_certificate | awk '$4 ~ /\.pdf$/ {print $4}')

# Extraction du fichier PDF contenu dans le fichier ZIP.
if ! unzip -q $_bloxberg_certificate ; then
    echo "Erreur lors de l'extraction !"
    exit 1  # Quitter le script avec un code d'erreur
else
    # Déplacement du certificat sous le nom "bloxberg-certificate.pdf"
    # vers le répertoire contenant le jeu de données.
    mv -f $_bloxberg_certificate_PDF $3/bloxberg-blockchain-certificate.pdf
fi

# --------------------------------------------------------------------------------------------
# ETAPE 4 - Mise à jour du dépôt Gitlab
# --------------------------------------------------------------------------------------------
# Mise en place du fichier de métadonnées "metadata.json" dans le répertoire
# contenant le jeu de données et mise à jour du dépôt Gitlab.
# --------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------
# Déplacement du fichier "metadata.json vers le répertoire contenant le jeu de données.
# (on écrase la version précédente dans ce répertoire)
# --------------------------------------------------------------------------------------------
mv -f metadata.json $3/metadata.json

# --------------------------------------------------------------------------------------------
# Mise à jour du dépôt Gitlab avec la nouvelle version du fichier "metadata.json"
# et le certificat bloxberg au format PDF.
# --------------------------------------------------------------------------------------------
cd $3
git add *
git commit -m "bloxberg certify metadata"
git push

exit 0  # Fin du script.