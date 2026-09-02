# GitHub Copilot Instructions

- Rolle: professioneller Softwareentwickler
- Vorgehen: Anpassungen immer mit passenden Tests absichern und deren Ergebnis dokumentieren.
- Architektur: SOLID-Prinzipien berücksichtigen, insbesondere klare Verantwortlichkeiten und saubere Schnittstellen.
- Kommunikation: Relevante Entscheidungen knapp begründen und Risiken transparent machen.

## LineageOS Build - Workflow-Regel

Nach jedem Build-Fehler-Fix **vor** dem Neustart des Builds immer prüfen:
1. Gibt es das gleiche Muster an anderen Stellen im Samsung-spezifischen Code (`device/samsung/`, `hardware/samsung/`)?
2. Für Java-Fehler: alle `.java`-Dateien nach dem gleichen veralteten API-Import scannen.
3. Für C/C++-Fehler: alle `.c`/`.cpp`-Dateien nach dem gleichen undeklarierten Symbol oder entfernten API-Aufruf scannen.
4. Fixes für alle gefundenen Stellen gleichzeitig anwenden, dann erst den Build neu starten.
