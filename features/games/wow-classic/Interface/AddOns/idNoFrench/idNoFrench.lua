-- Hides French lines in chat channels (General, Trade, LFG, custom). Say, guild, party, raid, whispers untouched.
-- Words: common French (FrequencyWords, OpenSubtitles 2018) that are not English (dwyl/english-words, top 50k English), plus a core list.
local W={}for w in([[
abandonne abandonné abandonner abruti absolument accepte accepté accès accompagner accusé acheté achète
acheter acte acteur admettre adn adresse adulte aéroport afin afrique âge agence agir agréable aidé aidera
aie aient aies aille ailleurs aimais aimait aime aimé aiment aimerais aimerait aimes aimez ainsi aise
alarme alcool alerte allais allait allé allée allés allô allons alors âme amené amène amener américain
américaine américains amérique amitié amoureuse amoureux amusant ancienne angleterre animaux année années
anniversaire annoncer appareil apparemment appartient appelait appelé appelée appeler appelez appelle
appellent appelles apporte apporté apporter apprécie apprendre appris approche approcher après arbre arbres
arme armée armes arrêt arrête arrêté arrêter arrêtes arrêtez arrière arrivé arrivée arrivent arrivera
arrivés assassiné asseoir assez associé attaque attaqué attaquer atteindre atteint attendais attendait
attendent attendez attendre attendu attente attrape attrapé attraper aucun aucune auprès aurai auraient
aurais aurait aurez auriez aurons auront aussi autant autour autrement autres aux avaient avais avait
avancer avec avenir avez aviez avocats avons ayant ayez bague baiser baisse balles bataille bâtiment battre
beaucoup beauté bébé bébés bête bibliothèque bien bientôt bière blessé blessure blessures boire boîte
bonheur bonjour bonne bouger bougez boulot bouteille bref brillant brisé brûle brûlé brûler ça caché cacher
cadavre cadeaux californie calme caméra caméras canapé cardiaque carrière casier cassé casser cela célèbre
célibataire celle celles celui censé censée centaines cependant cérémonie certaine certainement certaines
certains cerveau ces cesse cet cette ceux chaîne chaleur chanceux changé chante chaque chargé charmant
chaud chèque cherchais cherche cherché chercher cherches chère chéri cheveux chez chiens chier choc choisi
choisir choisis choix cible ciel cinéma cinq circonstances clairement classe classique clé clés clinique
cœur coffre coincé colère colle collègues combattre combien comité commande comme commencé commissaire
commun communauté complet complètement compliqué comportement comprendre comprends comprenez compris comptes
concentrer concernant concerne conduire conduis conférence confiance connais connaissais connaissait connaissance
connaissez connait connaît connaître connard conneries conseil conseiller conseils construire construit
contacter contente continuez contrat contre contrôle contrôler convaincre convaincu copine corde côte
côté côtés couché couilles coupable coupé cour courageux courir courrier coûte couverture couvrir crains
craint crâne créature crédit créé créer crétin criminel crise croient croire croit croyais croyez curieux
dangereux dans danse danser davantage débarrasser débile début décide décidé décider décision déclaration
découvert découvrir défendre défense dégage dégagez déjà déjeuner délicieux demandais demande demandé
demandes demandez démon départ département dépend depuis dérange déranger dernière dernières derniers
derrière des dès descendre désert désir désolé désolée désormais détails détective déteste détruire détruit
deux deuxième devais devait devenir devenu devenue devez deviens devient deviner devra devraient devrais
devrait devriez devrions dieux différence différent différente différentes différents dimanche dîner dingue
dira dirai dirais dirait directement disais disait disant discours discuter dise disent disiez disons
disparaître disparu docteur doigts dois doivent dommage donc donné données donnerai donnes donnez dormi
dormir doucement doué douleur doute droite drôle dû échange échappé échapper échoué école écoute écouté
écouter écoutes ecoutez écoutez écran écrire écris écrit également église élevé élève élèves elle elles
embrasser émission emmené emmène emmener emmerde empêche empêcher emploi employés empreintes endroit endroits
énergie enfance enfer enfoiré enfuir engagé enlevé enlève enlever ennemi ennemis ennuie énorme enquête
entend entendez entends entendu enterrement entière entièrement entraînement entré entreprise entretien
envers envie envoie envoyé envoyer envoyez épée épisode époque épouse épouser équipage équipe erreur erreurs
espèce espérais espère espérons espoir essaie essayais essayait essaye essayé essayez essayons est estomac
étage étaient étais etait était étant étape état été êtes étiez étions étoile étoiles étonnant étrange
étranger étrangers etre être études étudiants étudier euh eux évidemment évident éviter exactement excellente
excusez exemple existe expérience explique expliquer exploser extérieur facilement façon faible failli
faim faire fais faisais faisait faisant faisons fait faite faites fallait falloir fallu familles fantastique
fantôme fasse fasses fatigué fatiguée faudra faudrait fausse faut faveur félicitations fenêtre fera ferai
ferais ferait feras ferez feriez fermé fermer feront fête fier fière finalement finie finir finit fiston
fleurs flingue foi fois folle fonctionne forcé forcément forêt foule fous fout foutu frais franchement
frappé frapper frère frères fric froid frontière fuir fuite fumée futur gâcher gagne gagné gagner garçon
garçons gardé garder gardes gardez gardien gâteau gêne général génial géniale génie genoux gentille gérer
gloire gosse gosses goût gouvernement gouverneur grâce grandes grandi groupe gueule habite hais hâte hé
hein herbe héros heu heure heures heureuse heureusement heureux histoire histoires hommes honnête honnêtement
honneur honte hôpital horreur hôtel huit humain humaine humains humanité humeur ici idée idées identité
idiote ignorais il île ils imaginez imbécile immédiatement immeuble impliqué importante importe impressionnant
incendie infirmière informations inquiète inquiéter inquiétez inspecteur intelligente interdit intéressant
intéresse intérêt intérieur inventé invité invités irai irait jaloux jamais je jésus jeté jette jeudi
jeune jeunes joindre joli joue joué jouer joues joueur jouez jour journaliste journaux journée joyeux
juge jugement juré juste justement kilomètres là labo lâche lâcher laissé laissée laisser laisserai laisses
lancé laquelle larmes leçon lendemain lentement lequel les lettre lettres leur leurs lève lèvres libérer
liberté lieux limite liquide liste logique loi longtemps lorsque lui lundi lutte lycée magie magique maintenant
mais maisons maîtresse majesté maladie malgré malheureusement mangé manière manqué manquer manques marche
marché mariage marié mariée marier mariés marrant marre matériel mauvais mauvaise mauvaises mec méchant
mecs médecin médecine médecins médicaments meilleur meilleure meilleures meilleurs membre membres même
mêmes mémoire mène mener mensonge mensonges menteur menti mentir merci mère mérite merveilleuse mesure
métier mètres mettez mettre meurs meurt meurtre meurtres meurtrier miel mienne mieux militaire ministre
minuit modèle moi moindre moins mois moitié monnaie monstre monté monter montré montrer moque morte moteur
mourir mouvement moyens murs musique mystère nationale navire navré né nécessaire neige nerveux nettoyer
neuf noël noirs nombre nombreux nommé normale normalement notre nourrir nourriture nous nouvel nuits nulle
numéro objets obligé obtenir obtenu occupe occupé occupée occuper océan odeur oeil œil offert officier
offre offrir oiseau oiseaux oncle ont opération opportunité ordinateur ordre ordres oreille oreilles origine
où ouai ouais oublie oublié oublier oubliez ouest oui ouvrez ouvrir paie paix panique papiers paraît parce
pardonner parfaite parfaitement parfois parie parlais parlait parlant parlé parlent parler parlera parlez
parlons parmi partager partenaire partez particulier partir partout pas passait passée passent passera
passez pauvre pauvres paye payé peau pêche peinture pensais pensait pensé pensées pensent penser penses
pensez perd perdre perds père période permet permettez permettre permis personnage personne personnellement
personnes perte peu peuple peur peut peuvent peux pièce pièces pieds piège pilote pire pitié plainte plaisante
plaisantes plaisir planète plein pleine pleure pleurer pluie plupart plusieurs plutôt poids poitrine policier
portait porté portée portes posé possède poste potes poupée pourquoi pourra pourrai pourraient pourrais
pourrait pourras pourrez pourriez pourrions poursuivre pourtant poussé pousser pouvais pouvait pouvez
pouviez pouvoir pouvoirs pouvons précédemment préféré préfère première prend prendra prendrai prends prenez
prenne prennent prénom prépare préparé préparer près présence présent présente présenter président presque
presse prêt prête prêtre prêts preuve preuves prévenir prévenu prévu pris prisonnier prisonniers privé
privée probablement problème problèmes procès prochaine proche proches produit produits professeur professionnel
profond promesse promets promis propre propres propriétaire propriété protège protéger prouve prouver
puis puisque puisse pute qualité quand quartier quelles quelque quelques quels qui quiconque quitte quitté
quoi raconte raconté raconter racontes ramené ramène ramener rapidement rappeler rappelle rappelles raté
ravie réaction réalisé réaliser réalité récemment recevoir recherches récompense reconnais reconnu reçu
reculez récupérer réel réellement refaire réfléchi réfléchir réfléchis refusé regarde regardé regardes
regardez région réglé règle régler règles regrette reine rejoindre remarqué remercie remercier remettre
remis remonte remonter remplacer rempli rencard rencontré rencontrer rencontrés rendre rentre rentré rentrée
rentrer rentrez réparer répète répéter répond répondez répondre réponds répondu réponse réponses repos
reprendre représente réputation réseau réserve résoudre respecte respirer responsabilité ressemble ressens
reste resté restera restez résultat résultats retourne retourner retournez retraite retrouve retrouvé
retrouver réunion réussi réussir rêve rêvé réveille réveillé réveiller revenez revenir revenu rêves reviendra
reviendrai reviens revient rire rires risques rôle romantique roule royaume russes rythme sache saches
sacré sacrée saison sait salaire salaud salope salut samedi santé sauté sauvé sauver savais savait savent
savez saviez savoir savons scène scientifique secrétaire secrète secteur sécurité seins selon semaine
semaines semblait sénateur sens sentais sentez sentir seraient serait seras serez sergent série sérieuse
sérieusement sérieux seriez serons seront servi servir ses seule seulement seuls sexe shérif siècle siège
signé signes simplement société soeur sœur soi soient soif soin soirée sois soit soldats sommeil sommes
sonne sont sorcière sors sorte sortez sorti sortir souci soucis soudain souffre souffrir souhaite soupe
sourire souris soutien souvenez souvent souviens soyez soyons spécial spéciale stupide succès suffit suis
suivant suivi suivre sujet superbe supplie supposé sur sûr sûre sûrement surpris survécu surveille surveiller
survivre sympa système tâche taire tant tante tard technologie télé téléphone telle tellement témoin témoins
tempête tenir tente tenté tenu terme terminé terminée tête têtes thé théâtre théorie tienne tient tir
tiré tirez toi tombé tombée tomber tôt totalement touchez toujours tourné tournée tourner tous tout toute
toutes traîner traite traité traitement traiter tranquille travaillait travaille travaillé travailler
travailles travaillez traversé très trésor troisième trompé tromper trou trouve trouvé trouvée trouvent
trouver trouvera trouverai trouves trouvez truc trucs tu tué tuée tuer tués tueur une uniforme uniquement
unité univers université utilisé vacances vais vaisseau vaut vécu véhicule veille vélo venais venait venant
vendre vendredi vendu venez venir vente ventre vérifie vérifié vérifier véritable vérité verra verrai
verras verrez veste vêtements veuillez veulent veut veux victime victimes victoire vidéo vieil vieille
viendra vienne viennent viens vient vierge vieux viré virer vit vivante vivent voici voie voient vois
voisin voisins voit voix volé voler voleur volonté vont votre vôtre voudrais voudrait voulaient voulais
voulait voulez vouliez vouloir voulons voulu vous voyais voyez voyons vrai vraie vraiment vrais vus yeux
zéro
]]):gmatch("%S+")do W[w]=true end
local function f(_,_,m)
  local t=m:gsub("|H.-|h.-|h",""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("|T.-|t",""):lower()
  local n,c=0,0
  if t:find("ç")or t:find("ê")or t:find("î")or t:find("û")or t:find("ë")or t:find("ï")or t:find("œ")then n=1 end
  for w in t:gmatch("[%a\128-\255]+")do c=c+1 if W[w]then n=n+1 end end
  return n>1 or(n>0 and c<4)
end
(ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter)("CHAT_MSG_CHANNEL",f)
