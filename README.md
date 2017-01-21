# Projekt 'Grøn Registrering'
System til registrering af grønne områder i Frederikssund Kommune.


Af Casper Bertelsen, Have- og parkingenigørstuderende
Udarbejdet
- i forbindelse med praktikophold Sept '16 - Jan '17
- i samarbejde med
	Frederikssund Kommunes Vej & Park-afdeling
	Bo Victor Thomsen, Frederikssund Kommunes GIS-afdeling


Systemet er udarbejdet på baggrund af datamodellen fra det Fælles Kommunale Geodatasamarbejde (FKG) - Der vil derfor være elementer, som knytter sig hertil.

Systemet er bygget op af en databasestruktur i PostgreSQL / PostGIS, en QGIS-projektskabelon, samt en håndfuld Excel-filer, som danner diverse rapportfunktioner.

Alle filer er sat op til Frederikssund Kommunes interne server, og disse skal ændres til en anden server / localhost for at virke.

**f-pgsql01.ad.frederikssund.dk** erstattes med **localhost** eller anden tilgængelig server.
Alle logins til Excel-ark og QGIS benytter user: 'qgis_reader' password: 'qgis_reader'.


### Indhold

#### PostgreSQL / PostGIS

Databasenavn: groenreg

Databasestrukturen består af et sæt SQL scripts, som kan køres i PostgreSQL. Hovedscriptet ligger i mappen "SQL - Database".
Dette script danner den grundlæggende databasestruktur med tabeller, triggers mv.
I mappen er der et script til to login. Det ene er user: 'qgis_reader' password: 'qgis_reader', som giver adgang til filerne. Alternativt kan login på filerne ændres til en superuser.
Det andet login er user: 'backadm' password: 'qgis', som benyttes i et kommandoscript til hurtig backup af databasen.

Yderligere er der en mappe med en række views, "SQL - Views" (specifikke til Frederikssund Kommune), som er lavet i forbindelse med forskellige ønsker i Frederikssund Kommune.
Der er kommentar på alle disse scripts. De fleste benyttes i forbindelse med Excel-rapporter, mens nogle er en slags skabelon-scripts, som benytter funktioner med variabler i hovedscriptet.

#### QGIS

Version 2.18 er benyttet

I mappen QGIS ligger der en projektfil, samt en billedefil. Billedet benyttes i printskabeloner.

QGIS-projektet indeholder følgende struktur:
- Område (Lag)
- Skitsering (Gruppe)
  - Skitsering (Lag - hhv. flader, linier og punkter)
- Ændringer (Gruppe) (Findes i "SQL - Views")
  - Ændringer - 14 dage (Lag - hhv. flader, linier og punkter)
- ELEMENTER (Gruppe)
  - Punkter (Lag)
  - Linier (Lag)
  - Flader (Lag)
  - Label (Gruppe - vedr labels for individuelle elementer)
- Atlas (Gruppe)
  - Delområder (Lag)
  - Atlas_Områder (Lag)
  - Atlas_Punkter (Lag)
  - Atlas_Linier (Lag)
  - Atlas_Flader (Lag)
- Grunddata (Ikke tilgængelig) (Bliver til 'bad layers', da de er tilknyttet andre databaser i kommunen)
- Tabeller (Gruppe - Diverse tabeller uden geometri fra databasen)

#### Excel

For at benytte Excel-filerne, skal de fleste scripts fra "SQL - Views" være kørt ind i databasen.
Yderligere kræver det en 32-bit ODBC-driver, som følger med PostgreSQL Stack Builder, men den er også vedlagt her.