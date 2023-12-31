# bloxberg certify metadata

## Description

Ce script d'exemple en bash génère un fichier de métadonnées pour un jeu de données puis, en utilisant l'[API bloxberg](https://certify.bloxberg.org/docs), il certifie ce fichier de métadonnées sur la blockchain [bloxberg](https://bloxberg.org/) et télécharge le certificat correspondant.

Puisqu'il fait appel à l'API bloxberg ce script peut être adapté dans n'importe quel langage de programmation.<br>
Il peut ainsi être intégré à n'importe quel logiciel open source existant pour authentifier et certifier des données sur la blockchain bloxberg.

### bloxberg

bloxberg (sans b majuscule) est la blockchain pour la science avec le plus grand réseau de PoA (Proof of Authority) au monde, géré uniquement par des organismes de recherche.<br>
La mission de bloxberg est de faire progresser la science avec sa propre infrastructure de blockchain et de permettre à la société dans son ensemble de sécuriser les données.<br>
Dédiée à cette mission, l'association bloxberg facilite et accélère l'usage de la blockchain décentralisée bloxberg et les applications scientifiques fonctionnant sur cette blockchain.

## Usage

Lancez le script avec comme paramètres votre clé API bloxberg, l'adresse de votre wallet bloxberg et le chemin vers le jeu de données.

`./metadata-bloxberg-certify.sh CLÉ_API_BLOXBERG WALLET_BLOXBERG REPERTOIRE_JEU_DE_DONNÉES`

## Prérequis

Ce script fonctionne sous Linux, assurez-vous que les programmes suivants soient installés :

CURL, JQ, GIT, UNZIP

Vous devez également posséder :

- Une une clé [API bloxberg](https://certify.bloxberg.org/docs)
- Une [adresse de portefeuille](https://blockexplorer.bloxberg.org/address/0xC604ffa8adE14dc9A22B6B19bdFC07E489156E53/transactions) (Wallet address) sur la blockchain bloxberg
- Un dépôt sur une plateforme de type [ForgeMIA](https://forgemia.inra.fr/), [Gitlab](https://gitlab.com/), [Github](https://github.com/)...

## Support

Pour toute question vous pouvez vous adresser à :<br>
Cédric GOBY : [cedric.goby@inrae.fr](mailto:cedric.goby@inrae.fr)

## Auteur

Cédric GOBY ([Agap Institut](https://umr-agap.cirad.fr/)) - [ORCID 0009-0004-8417-3677](https://orcid.org/0009-0004-8417-3677)

## Licence

[GNU General Public License v3.0 or later](https://www.gnu.org/licenses/gpl-3.0-standalone.html)

