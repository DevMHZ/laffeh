# Laffah — Politique de confidentialité

**Date d'entrée en vigueur :** 25 juillet 2026  
**Dernière mise à jour :** 25 juillet 2026

---

## 1. Qui nous sommes

Laffah (« l'application ») est une application de planification d'itinéraires
éditée par Ali Alzoobi, développeur indépendant établi au Liban,
exerçant sous le nom commercial « Afdal » (« nous »). « Afdal » est un nom
commercial et non une société immatriculée.

Nous sommes le responsable du traitement des données personnelles décrites dans
la présente politique.

**Contact pour toute question ou demande relative à la confidentialité :**
WhatsApp **+33 7 83 71 94 27**

---

## 2. En résumé

| | |
|---|---|
| Un compte est-il nécessaire ? | Non. L'application fonctionne intégralement sans connexion. |
| Affichons-nous de la publicité ? | Non. |
| Utilisons-nous des outils d'analyse ou de pistage ? | **Non.** L'application ne contient aucun SDK d'analyse, de publicité, de rapport de plantage ou d'attribution. |
| Vendons-nous vos données ? | Non. Jamais. |
| Vous suivons-nous en arrière-plan ? | Non. La position n'est lue que lorsque l'application est ouverte. |
| Combien de temps conservons-nous votre position ? | Nous conservons **une seule** position actuelle par appareil. Chaque nouvelle lecture remplace la précédente — nous ne constituons pas d'historique de déplacements. |

---

## 3. Ce que nous collectons

### 3.1 Données de compte — uniquement si vous choisissez de vous inscrire

L'inscription est facultative. Si vous créez un compte, nous collectons :

- **Votre numéro de téléphone** — il constitue votre identifiant de connexion.
- **Votre mot de passe** — stocké uniquement sous forme d'empreinte
  cryptographique par notre prestataire d'authentification. Nous ne voyons ni ne
  stockons jamais votre mot de passe en clair.

### 3.2 Données de profil — uniquement si vous complétez l'intégration

- Votre **nom complet**
- Le **nom de votre société**
- Les **cas d'usage** que vous sélectionnez (livraison, vente terrain,
  navigation, etc.)
- Un **texte libre facultatif**, collecté uniquement si vous choisissez « Autre
  utilisation » et saisissez quelque chose.

### 3.3 Données de localisation

- **Quoi :** latitude, longitude, rayon de précision en mètres et heure de la
  lecture.
- **Quand :** une seule lecture à chaque ouverture de l'application. Celle-ci
  demande une position de précision réduite (environ 100 m) plutôt qu'un GPS de
  pleine précision.
- **Au premier plan uniquement.** L'application ne lit pas votre position
  lorsqu'elle est fermée ou en arrière-plan.
- **Avec votre autorisation uniquement.** Si vous n'avez pas accordé
  l'autorisation de localisation, l'application passe cette étape en silence et
  ne vous la redemande jamais ici.
- **Un seul enregistrement, écrasé.** Nous stockons exactement une position
  actuelle par appareil, et la lecture suivante la remplace. Nous ne conservons
  aucune trace ni historique de vos déplacements.

### 3.4 Identifiant d'appareil

L'application génère un **identifiant aléatoire** au premier lancement et le
stocke sur votre appareil. Ce n'est ni votre identifiant publicitaire, ni un
numéro de série matériel, ni un identifiant attribué par Apple, Google ou votre
opérateur. Il sert à rattacher votre position actuelle à un appareil, y compris
lorsque vous n'êtes pas connecté.

### 3.5 Ce que nous **ne** collectons **pas**

Nous ne collectons ni vos contacts, ni vos photos, ni votre agenda, ni le
microphone, ni la caméra, ni vos appels ou SMS, ni la liste des applications
installées, ni votre identifiant publicitaire, ni aucune donnée d'analyse
comportementale. L'application ne contient aucun code de pistage tiers.

---

## 4. Données qui ne quittent jamais votre appareil

Les éléments suivants sont stockés **uniquement** dans la mémoire locale de
votre appareil et ne nous sont jamais transmis :

- Vos **itinéraires enregistrés** et leur historique
- Vos **brouillons d'itinéraires** en cours
- Vos préférences de **langue, de thème et d'icône de véhicule**
- Les indicateurs d'intégration et de premier lancement

La désinstallation de l'application supprime le tout. Si vous exportez un
itinéraire au format CSV et le partagez, ce fichier va là où **vous** l'envoyez —
nous n'y sommes pas associés.

---

## 5. Avec qui nous partageons les données

Nous ne vendons pas vos données et ne les partageons pas à des fins
publicitaires. Les données ne parviennent aux tiers suivants que dans la mesure
nécessaire au fonctionnement de l'application :

| Destinataire | Ce qu'il reçoit | Pourquoi |
|---|---|---|
| **Supabase** (hébergeur de notre base de données et de l'authentification) | Votre compte, votre profil et votre position actuelle | Hébergement de notre back-end |
| **Service d'optimisation Afdal** (`back.laffa.afdal.tech`, exploité par nous) | Les **coordonnées** de votre dépôt et de vos arrêts, ainsi que le nombre et la capacité des véhicules | Calcul de l'itinéraire optimisé. Aucun nom, numéro de téléphone ou identifiant de compte n'est transmis. |
| **OpenStreetMap / Nominatim** | Le **texte que vous saisissez dans la recherche** et des coordonnées lors de la recherche d'une adresse | Recherche de lieux et nommage d'un point sur la carte |
| **OSRM** (`router.project-osrm.org`) | Les **coordonnées** de vos points d'itinéraire | Calcul du trajet routier entre les points |
| **OpenFreeMap** | La **zone de carte que vous consultez** | Fourniture des tuiles cartographiques |

OpenStreetMap, Nominatim, OSRM et OpenFreeMap sont des services publics
indépendants disposant de leurs propres pratiques de confidentialité. Nous ne
leur transmettons aucune information de compte — uniquement les coordonnées ou
le texte de recherche nécessaires à la requête.

Lorsque vous appuyez sur « Contacter le support », « Ouvrir dans Google Maps »
ou « Ouvrir dans Plans », l'application passe la main à cette application. Rien
n'est envoyé automatiquement ; cela n'a lieu que sur votre action.

Nous pouvons également divulguer des données si la loi nous y oblige.

---

## 6. Utiliser l'application sans compte

Vous pouvez ignorer la connexion et utiliser pleinement l'application. Nous le
précisons clairement :

**Même sans compte, l'application enregistre une position actuelle par
appareil**, rattachée à l'identifiant aléatoire décrit à la section 3.4, si vous
avez accordé l'autorisation de localisation. Elle n'est liée ni à votre nom ni à
votre numéro, puisque nous ne les possédons pas.

Si vous ne le souhaitez pas, refusez ou révoquez l'autorisation de localisation
dans les réglages de votre appareil. L'application continuera de fonctionner :
elle n'enregistrera simplement aucune position.

---

## 7. Base légale (pour les utilisateurs de l'EEE/UE)

| Finalité | Base légale |
|---|---|
| Création et fonctionnement de votre compte | Exécution d'un contrat (art. 6.1.b RGPD) |
| Optimisation et affichage des itinéraires | Exécution d'un contrat (art. 6.1.b RGPD) |
| Collecte de votre position actuelle | Votre **consentement**, donné via la demande d'autorisation du système (art. 6.1.a RGPD). Vous pouvez le retirer à tout moment dans les réglages de votre appareil. |
| Comprendre le profil de nos utilisateurs (société, cas d'usage) | Intérêt légitime (art. 6.1.f RGPD) |

---

## 8. Durées de conservation

- **Position actuelle :** un enregistrement par appareil, écrasé en continu.
  Aucun historique de déplacements.
- **Données de compte et de profil :** jusqu'à la suppression de votre compte.
- **À la suppression de votre compte :** votre numéro de téléphone, vos
  identifiants, votre nom, votre société, vos cas d'usage sélectionnés et votre
  position enregistrée sont définitivement supprimés de notre base. La
  suppression est immédiate et irréversible.

---

## 9. Vos droits

Vous pouvez nous demander :

- L'**accès** aux données que nous détenons sur vous
- La **rectification** des données inexactes
- La **suppression** de votre compte et de vos données
- L'**opposition** au traitement ou sa **limitation**
- Une **copie portable** de vos données

**Pour supprimer votre compte vous-même, à tout moment :**
Ouvrez l'application → **Réglages** → **Compte** → **Supprimer le compte**.
La suppression est immédiate et définitive.

Vous pouvez également demander la suppression, ou exercer tout autre droit, en
nous contactant sur WhatsApp au **+33 7 83 71 94 27**. Nous nous efforçons de
répondre sous 30 jours.

**Si vous résidez dans l'EEE/UE**, vous disposez en outre du droit d'introduire
une réclamation auprès de votre autorité nationale de protection des données
(en France, la CNIL).

---

## 10. Sécurité

- Toutes les communications avec nos serveurs utilisent des connexions chiffrées
  HTTPS/TLS.
- Les mots de passe ne sont stockés que sous forme d'empreintes cryptographiques,
  jamais en clair.
- L'accès à la base est restreint par des règles de sécurité au niveau des
  lignes, de sorte qu'un utilisateur ne peut pas lire les enregistrements d'un
  autre.

**Une limite que nous préférons énoncer clairement :** pour simplifier
l'inscription, nous **ne** vérifions **pas** les numéros de téléphone par code
SMS. Un numéro dans notre système équivaut donc à un nom d'utilisateur, et nous
n'avons aucune preuve que la personne qui l'a enregistré en est titulaire. Pour
cette raison, nous ne pouvons pas non plus proposer de récupération automatique
du mot de passe — l'assistance passe par notre canal de support. Ne considérez
donc pas votre compte Laffah comme un justificatif d'identité sécurisé, et
utilisez un mot de passe que vous ne réutilisez pas ailleurs.

---

## 11. Enfants

Laffah ne s'adresse pas aux enfants et n'est pas destinée aux personnes de moins
de 16 ans. Nous ne collectons pas sciemment de données d'enfants. Si vous pensez
qu'un enfant nous a fourni des données, contactez-nous et nous les supprimerons.

---

## 12. Transferts internationaux

Notre infrastructure back-end est hébergée chez Supabase, et notre service
d'optimisation ainsi que les services cartographiques listés à la section 5
peuvent traiter des données sur des serveurs situés hors de votre pays, y
compris hors du Liban et de l'EEE. Lorsque des données d'utilisateurs de l'EEE
sont transférées hors de l'EEE, nous nous appuyons sur des garanties appropriées
telles que les clauses contractuelles types de la Commission européenne.

---

## 13. Modifications de la présente politique

En cas de modification, nous mettrons à jour la date de « Dernière mise à jour »
ci-dessus et publierons la nouvelle version à cette adresse. Les changements
substantiels seront annoncés dans l'application.

---

## 14. Droit applicable

La présente politique est régie par le droit **libanais**, et les tribunaux de
Beyrouth sont compétents pour tout litige en découlant.

Si vous résidez dans l'EEE/UE, rien dans la présente politique ne vous prive des
droits garantis par le RGPD ni par les dispositions impératives du droit de
votre pays de résidence.
