#!/usr/bin/env bash
#
# Description : Ce script génère un fichier de métadonnées pour un jeu de données puis, en utilisant
# l'API bloxberg, il certifie ce fichier de métadonnées sur la blockchain bloxberg
# et télécharge le certificat correspondant.
# Usage : ./metadata-bloxberg-certify.sh BLOXBERG_API_KEY BLOXBERG_WALLET_ADDRESS
# Référence API bloxberg : https://certify.bloxberg.org/docs
# Licence : GPL-3+ (https://www.gnu.org/licenses/gpl-3.0.txt)
# Auteur : Cédric Goby
# Versioning : https://forgemia.inra.fr/blockchain-esr/bloxberg-certify-metadata

# Vérifier si la clef API et l'adresse du wallet bloxberg ont été fournies comme paramètres positionnels
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Vous n'avez pas fourni votre clé API bloxberg et/ou l'adresse de votre wallet bloxberg"
  echo "Usage : ./metadata-bloxberg-certify.sh BLOXBERG_API_KEY BLOXBERG_WALLET_ADDRESS"
  exit 1  # Quitter le script avec un code d'erreur
fi

# --------------------------------------------------------------------------------------------
# Génération du fichier de métadonnées "metadata.json" pour un jeu de données.
# --------------------------------------------------------------------------------------------
# Chemin du répertoire contenant le jeu de données.
# *** Dans l'exemple ci-dessous il s'agit d'un répertoire local contenant des newsletters mensuelles sur la sécurité informatique au format MARKDOWN.
# *** Chaque mois la nouvelle newsletter est envoyée (push) sur Gitlab : https://gitlab.com/CedricGoby/newsletter-securite-informatique/ 
# *** ainsi que le nouveau fichier "metadata.json" incluant cette nouvelle newsletter (un nouveau fichier MARDOWN).
_dataset_folder=/home/cedric/Documents/DEV/scripts-rss/newsletter-securite-informatique
# Nom du fichier de métadonnées.
_metadata_file=metadata.json
# Réinitialisation du fichier.
>$_metadata_file

# Insertion du début du fichier de métadonnées.
# *** Utilisation du standard DUBLIN CORE (https://www.dublincore.org/specifications/dublin-core/dcmi-terms/),
# *** du standard PREMIS (https://www.loc.gov/standards/premis/)
# *** et du format JSON-LD (https://www.w3.org/TR/json-ld11/) pour décrire le jeu de données.
cat >$_metadata_file << EOF
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
  "dc:date": "$(date -u "+%Y-%m-%dT%H:%M:%S.%NZ" | sed 's/.\{6\}$//' | sed 's/$/Z/')",
  "dc:description": "Cette revue de presse généraliste et mensuelle a pour but de sensibiliser le public aux problématiques de la sécurité informatique.",
  "dc:publisher": [
    "http://viaf.org/viaf/3881157583857733970006",
    "http://viaf.org/viaf/314926296"
  ],
  "dc:rights":"http://spdx.org/licenses/CC-BY-NC-SA-4.0.json",
  "dc:identifier": [
EOF

# On classe les fichier MARKDOWN par date pour plus de clarté.
for _file in $(ls -t $_dataset_folder/*.md); do
# On insert l'URI et la SOMME DE CONTRÔLE de chaque fichier MARKDOWN (.md) dans le fichier de métadonnées "metadata.json".
# *** Dans notre exemple l'URI correspond à l'URL Gitlab de chaque fichier MARKDOWN (URL pérennes tant que le dépôt existe).
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
# Suppression de la dernière ligne du fichier pour retirer "},"
sed -i '$d' "$_metadata_file"
# Clotûre du fichier de métadonnées.
cat >>$_metadata_file << EOF
     }
   ]
 }
EOF

# TODO : Générer un fichier README.txt (lisible par les humains) à partir du fichier de métadonnées JSON.

# --------------------------------------------------------------------------------------------
# Écriture dans un fichier TEMPORAIRE de la valeur JSON pour la clé "metadataJson" de l'API bloxberg.
# --------------------------------------------------------------------------------------------
# Nom du fichier TEMPORAIRE contenant la valeur pour la clé "metadataJson".
_metadataJson="metadataJson.json"
# Création du fichier TEMPORAIRE
touch $_metadataJson

# Écriture de la valeur JSON pour la clé "metadataJson" dans le fichier TEMPORAIRE en utilisant le DUBLIN CORE.
# *** Dans notre exemple "dc:identifier" correspond à l'URL Gitlab du fichier "metadata.json" (URL pérenne tant que le dépôt existe):
# *** https://gitlab.com/CedricGoby/newsletter-securite-informatique/-/blob/master/metadata.json
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
  "dc:rights":"https://creativecommons.org/licenses/by/4.0/",
  "dc:identifier": {
    "@value": "https://gitlab.com/CedricGoby/newsletter-securite-informatique/-/blob/master/$_metadata_file",
    "@type": "http://purl.org/dc/terms/URI"
    }
}
EOF

# --------------------------------------------------------------------------------------------
# Appel à l'API bloxberg pour certifier le fichier de métadonnées "metadata.json".
# --------------------------------------------------------------------------------------------
# Clé API fournie par bloxberg (Paramètre positionnel 1).
_api_key="$1"
# Adresse du wallet bloxberg (Paramètre positionnel 2).
_public_key="$2"
# SOMME DE CONTRÔLE du fichier de métadonnées "metadata.json" (crid = Content Reference IDentifier).
_crid=$(sha256sum "$_metadata_file" | awk '{print $1}')
# A partir du fichier TEMPORAIRE on formate la valeur de la clé "metadataJson" pour l'API.
_metadataJson=$(cat $_metadataJson | jq -c . | sed -e 's/"/\\"/g')
# Nom du fichier TEMPORAIRE contenant la réponse JSON de l'API.
_json_response=json_response.json
## Création du fichier TEMPORAIRE
touch $_json_response
# Nom du fichier de logs (Erreurs).
_error_log=error.log

# Envoi de la requête CURL, écriture de la réponse JSON de l'API dans un fichier,
# récupération du code de réponse HTTP.
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

# Vérification du code de retour HTTP (Code 200 attendu).
if [ ${_http_request} -ne 200 ] ; then
    echo "$(date) - HTTP error : $_http_request" | tee -a $_error_log
    exit 1
fi

# Vérification de la validité de la réponse JSON.
# Début de la séquence JSON attendue.
_expected_json_response='[{"@context":["https://www.w3.org/2018/credentials/v1",'
# Formatage de la réponse JSON sur une ligne.
_one_line_json_response=$(jq -c . $_json_response)
# Erreur si la réponse ne commence pas par la séquence attendue, écriture de la (mauvaise) réponse
# dans le fichier de log.
if [[ ! "$_one_line_json_response" =~ ^"$_expected_json_response" ]]; then
    echo "$(date) - JSON error : $(cat $_json_response)" | tee -a $_error_log
    exit 1
fi

# --------------------------------------------------------------------------------------------
# Appel à l'API bloxberg pour générer le certificat au format PDF et le télécharger en tant
# qu'archive ZIP.
# --------------------------------------------------------------------------------------------
# Nom du fichier ZIP contenant le certificat au format PDF.
_bloxberg_certificate=bloxberg-certificate-$_crid.zip

# Envoi de la requête CURL
# TODO : Insérer la réponse JSON (-d '').
# TODO : Récupérer et vérifier le code de réponse HTTP.
# TODO : Vérifier la validité du fichier téléchargé.
# TODO : Extraire l'archive.
curl -X 'POST' \
  'https://certify.bloxberg.org/generatePDF' \
  -H 'accept: application/json' \
  -H 'api_key: '"$_api_key"'' \
  -H 'Content-Type: application/json' \
  -d ''"$(cat $_json_response)"'' -o $_bloxberg_certificate

# Suppression du fichier TEMPORAIRE contenant la valeur pour la clé "metadataJson".
rm $_metadataJson
# Suppression du fichier TEMPORAIRE  contenant la réponse JSON de l'API.
rm $_json_response

# Déplacement du fichier "metadata.json" vers le répertoire contenant le jeu de données (en écrasant le fichier "metadata.json" existant).
# *** Dans notre exemple on déplace le fichier "metadata.json" dans le répertoire local /home/cedric/newsletter-securite-informatique
# *** contenant les newsletters mensuelles sur la sécurité informatique.
mv -f $_metadataJson $_dataset_folder/$_metadataJson

# Mise à jour du dépôt Gitlab avec le nouveau fichier "metadata.json"
# *** Dans notre exemple on envoi (push) le fichier /home/cedric/newsletter-securite-informatique/metadata.json vers
# *** le dépôt https://gitlab.com/CedricGoby/newsletter-securite-informatique/
cd $_dataset_folder
git add $_metadataJson
git commit -m "Ajout du fichier de métadonnées"
git push

exit 0  # Fin du script.