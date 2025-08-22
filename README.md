# TiefenGeschichten (World of Warcraft Addon)

Ein schlankes Addon, das dir bei den **Tiefen-Erfolgen** hilft. Es zeigt dir in einem einfachen Fenster **alle noch fehlenden Geschichtsvariationen** („Erfolgsschritte“) aus passenden Erfolgen und **markiert** die Variation, die du gerade am Tiefeneingang siehst.

---

## Was das Addon macht

- **Fehlende Geschichten anzeigen**  
  Listet automatisch alle **noch offenen Kriterien** aus Erfolgen, die zu den Tiefen-Geschichten gehören:

- **Aktive Geschichtsvariation erkennen**  
  Wenn du die Karte öffnest und mit der Maus über einen **Tiefen-Eingang** hoverst, erkennt das Addon die **„Geschichtsvariation: …“** aus dem Tooltip und **gleicht sie mit deiner Liste ab**.

- **Visuelles Markieren (Magenta)**  
  Passt die **Schriftfarbe** der passenden Variation in deiner Liste an: **weiß → magenta**. So siehst du auf einen Blick, ob der gerade aktive Strang eine deiner offenen Varianten ist.

- **Persistenz & Auto-Reset**  
  Markierungen bleiben **accountweit** erhalten – auch nach **/reload** und **Charakterwechsel**. Zum **täglichen Server-Reset** werden alle Markierungen **automatisch** zurückgesetzt.

- **Performance-freundlich**  
  - Achievement-Scan läuft **lazy & in kleinen Happen** (kein UI-Hänger beim Login).
  - Tooltip-Erkennung ist **gedrosselt** und nur aktiv, wenn ein Tooltip sichtbar ist.
  - Kein permanentes Scannen im Hintergrund.

---

## Installation

1. Lade das Repository als **ZIP** herunter oder klone es.
2. Entpacke/lege den Ordner **`TiefenGeschichten`** nach:
   - Retail: `[World of Warcraft Pfad]/_retail_/Interface/AddOns/`
3. Starte WoW neu oder nutze **/reload** im Spiel.

---

## Verwendung

- Öffne/Schließe das Addon-Fenster mit **`/tgs`**. Die Aktualisierung der Liste kann etwas Zeit in Anspruch nehmen.  
- Öffne die **Karte** und **hovere** mit der Maus über einen **Tiefeneingang**.  
  → Der Tooltip liefert „**Geschichtsvariation: XYZ**“ und die Variation **XYZ** wird ggf. in deiner Liste **magenta** markiert (und gespeichert).

**Hinweise**
- Die Liste zeigt nur **noch fehlende** Variationen; fertiggestellte werden ausgeblendet.
- Markierungen bleiben erhalten, bis sie zum täglichen **Server-Reset** auto‑gelöscht werden.

---

## Slash-Befehle

- **`/tgs`** – Fenster ein/aus.
- **`/tgs refresh`** – Erfolge neu scannen.
- **`/tgs debug`** – Debug-Ausgabe umschalten (liest und zeigt Tooltip-Texte).
- **`/tgs clear`** – Alle gespeicherten Markierungen löschen.
- **`/tgs reset`** – Reset‑Uhr neu setzen (falls nötig).
- **`/tgs dump`** – Kurze Statistik der gespeicherten Markierungen ausgeben.

---

## Kompatibilität

- Getestet mit **The War Within** (Interface `110000`).  
- Läuft **NUR** mit **deutscher** Client-Sprache (Tooltip-Texte „Geschichtsvariation: …“).

---

## Lizenz

- **Lizenz:** GPL-3.0 license 

Viel Spaß & happy hunting! 💜
