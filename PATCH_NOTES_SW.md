# ADDO Manager — Marekebisho ya Premium UI

## Muonekano mpya
- Rangi kuu: navy ya kina `#102A43`, teal `#087E78`, na gold `#D6A84F`.
- Dashboard mpya yenye hero banner, takwimu za leo, vitendo vikuu na tiles za usimamizi.
- Login screen mpya yenye background ya gradient, paneli safi na inputs zilizoboreshwa.
- Theme ya pamoja kwa app bars, buttons, inputs na lugha ya Material 3.
- Mpangilio unaojirekebisha kwa upana wa simu; maandishi marefu ya takwimu yanapunguzwa kwa usalama.

## Marekebisho ya logic
- Orodha ya expiry sasa inaonyesha pia legacy stock iliyobaki hata kama dawa hiyo ina batch mpya.
- Kuongeza supplier na audit log yake sasa hufanyika ndani ya transaction moja.
- Malipo ya supplier sasa yanaandikwa kwenye audit log ndani ya transaction.
- Marekebisho ya awali ya FEFO, batch cost/profit, matumizi na audit log yamehifadhiwa.

## Mambo ambayo bado hayajathibitishwa/kukamilika
- Flutter SDK haipo kwenye mazingira haya; `flutter pub get`, `flutter analyze`, tests na APK build havijaendeshwa.
- Mfumo bado unahitaji password KDF ya kisasa, login lockout, roles, encrypted/validated backup, cart ya bidhaa nyingi, returns/refunds, reports za PDF/XLSX na tests za DB.
- ZIP ya source bado haina Android Gradle project wala `codemagic.yaml`; si APK-ready moja kwa moja.

## Maboresho ya awamu hii
- Database schema version 5: stock movement ledger na sale returns.
- Marekebisho ya stock yanafanyika kwa sababu na kuhifadhi historia; yameunganishwa kwenye ukurasa wa dawa.
- Manunuzi, mauzo, marekebisho na marejesho yanaingiza stock movement records.
- Ripoti sasa ina tarehe ya kuanzia/mpaka na inaonyesha mauzo, faida ghafi, matumizi na faida baada ya matumizi; CSV husafirisha rekodi za kipindi kilichochaguliwa.
- Customer statement query imeongezwa kwenye database layer.
- Credential mpya na zilizothibitishwa kwa mafanikio zinatumia PBKDF2-HMAC-SHA256; hash za zamani hubadilishwa wakati mtumiaji anapoingia kwa mafanikio.
- Marejesho ya mauzo yanaweza kurekodiwa kupitia database method `returnSale`; bado hayajawekewa kitufe cha UI kwenye historia ya mauzo.

## Mambo ambayo bado hayajakamilika
- Multi-item cart/risiti moja, UI ya returns/refunds, customer statement screen na supplier invoice allocation.
- PDF/XLSX halisi (ripoti bado ni CSV inayofunguka Excel).
- Login lockout, first-run forced credential setup na encryption ya database/backup.
- Android platform folder, signing, CI/Codemagic workflow na APK.
- Flutter analyze, automated tests na device QA hazijatekelezwa kwenye mazingira haya.

- Ulinzi wa kuingia: majaribio 5 yasiyo sahihi husababisha kufungwa kwa akaunti kwa dakika 5; password/PIN zinatumia PBKDF2-HMAC-SHA256 baada ya kubadilishwa au baada ya login ya kwanza yenye mafanikio.
- Mauzo ya bidhaa nyingi sasa yanahifadhiwa chini ya namba moja ya risiti.
- Marejesho yana UI ya kurekodi kwenye historia ya mauzo; hakikisha deni/malipo ya mkopo yanarekebishwa kwa utaratibu wa biashara kabla ya matumizi ya production.
- Codemagic workflow imeongezwa ili kutengeneza Android platform folder na kujaribu build ya APK.
