# Laffah — Privacy Policy

**Effective date:** 25 July 2026  
**Last updated:** 25 July 2026

---

## 1. Who we are

Laffah ("the app") is a route-planning application published by
Ali Alzoobi, an independent developer based in Lebanon, operating under
the trading name "Afdal" ("we", "us"). "Afdal" is a trading name, not a
registered company.

We are the data controller for the personal data described in this policy.

**Contact for any privacy question or request:**
WhatsApp **+33 7 83 71 94 27**

---

## 2. Summary

| | |
|---|---|
| Do we need an account? | No. The app works fully without signing in. |
| Do we show ads? | No. |
| Do we use analytics or tracking SDKs? | **No.** The app contains no analytics, advertising, crash-reporting or attribution SDK of any kind. |
| Do we sell your data? | No. Never. |
| Do we track you in the background? | No. Location is read only while the app is open. |
| How long do we keep your location? | We keep **one** current location per device. Each new reading overwrites the previous one — we do not build a location history. |

---

## 3. What we collect

### 3.1 Account data — only if you choose to sign up

Signing in is optional. If you create an account we collect:

- **Your phone number** — it is your login identifier.
- **Your password** — stored only as a cryptographic hash by our authentication
  provider. We never see or store your password in readable form.

### 3.2 Profile data — only if you complete onboarding

- Your **full name**
- Your **company name**
- The **use cases** you select (for example delivery, field sales, navigation)
- An optional **free-text note**, collected only if you select "Other use" and
  type something in the box

### 3.3 Location data

- **What:** latitude, longitude, an accuracy radius in metres, and the time of
  the reading.
- **When:** a single reading each time you open the app. The app requests a
  reduced-precision fix (approximately 100 m target accuracy) rather than
  full-precision GPS.
- **Only in the foreground.** The app does not read your location while it is
  closed or in the background.
- **Only with your permission.** If you have not granted location permission,
  the app silently skips this and never re-prompts you here.
- **One record, overwritten.** We store exactly one current location per device.
  The next reading replaces it. We do not keep a trail or history of where you
  have been.

### 3.4 Device identifier

The app generates a **random identifier** the first time it runs and stores it
on your device. It is not your advertising ID, your hardware serial, or any
identifier assigned by Apple, Google or your carrier. It is used to attach your
current location to a device, including when you are not signed in.

### 3.5 What we do **not** collect

We do not collect your contacts, photos, calendar, microphone, camera, call or
SMS data, installed-app list, advertising identifier, or any behavioural
analytics. The app contains no third-party tracking code.

---

## 4. Data that never leaves your device

The following is stored **only** in your device's local storage and is never
transmitted to us:

- Your **saved routes** and route history
- Your **in-progress route drafts**
- Your **language, theme and vehicle-icon preferences**
- Onboarding and first-run flags

Deleting the app removes all of it. If you export a route as a CSV file and
share it, that file goes wherever *you* send it — we are not involved.

---

## 5. Who we share data with

We do not sell your data and we do not share it for advertising. Data reaches
the following parties only as needed to make the app work:

| Recipient | What they receive | Why |
|---|---|---|
| **Supabase** (our database and authentication host) | Your account, profile and current-location record | Hosting our backend |
| **Afdal route-optimisation service** (`back.laffa.afdal.tech`, operated by us) | The **coordinates** of your depot and stops, plus vehicle count and capacity | Calculating an optimised route. No name, phone number or account identifier is sent. |
| **OpenStreetMap / Nominatim** | The **text you type into search**, and coordinates when the app looks up an address | Searching for places and naming a point on the map |
| **OSRM** (`router.project-osrm.org`) | The **coordinates** of your route points | Calculating the road path between points |
| **OpenFreeMap** | The **map area you are viewing** | Serving map tiles |

OpenStreetMap, Nominatim, OSRM and OpenFreeMap are independent public services
with their own privacy practices. We send them no account information — only the
coordinates or search text needed for the request.

When you tap "Contact support", "Open in Google Maps" or "Open in Apple Maps",
the app hands off to that application. Nothing is sent automatically; that only
happens when you tap.

We may also disclose data if we are legally required to do so.

---

## 6. Using the app without an account

You can skip sign-in and use the app fully. Please note clearly:

**Even without an account, the app records one current location per device**,
linked to the random device identifier described in section 3.4, if you have
granted location permission. It is not linked to your name or phone number,
because we do not have them.

If you do not want this, deny or revoke the location permission in your device
settings. The app will keep working; it simply will not store a location.

---

## 7. Legal basis (for users in the EEA/EU)

| Purpose | Legal basis |
|---|---|
| Creating and running your account | Performance of a contract (Art. 6(1)(b) GDPR) |
| Optimising and displaying routes | Performance of a contract (Art. 6(1)(b) GDPR) |
| Collecting your current location | Your **consent**, given through the operating-system permission prompt (Art. 6(1)(a) GDPR). You may withdraw it at any time in your device settings. |
| Understanding who our users are (company, use cases) | Legitimate interests (Art. 6(1)(f) GDPR) |

---

## 8. How long we keep data

- **Current location:** one record per device, continuously overwritten. There
  is no historical trail.
- **Account and profile data:** until you delete your account.
- **When you delete your account:** your phone number, credentials, name,
  company, selected use cases and stored location are permanently deleted from
  our database. This is immediate and irreversible.

---

## 9. Your rights

You may ask us to:

- **Access** the data we hold about you
- **Correct** inaccurate data
- **Delete** your account and data
- **Object to** or **restrict** our processing
- **Receive a copy** of your data in a portable format

**Deleting your account yourself, at any time:**
Open the app → **Settings** → **Account** → **Delete account**.
The deletion is immediate and permanent.

You can also request deletion, or exercise any other right, by contacting us on
WhatsApp at **+33 7 83 71 94 27**. We aim to respond within 30 days.

**If you are in the EEA/EU**, you additionally have the right to lodge a
complaint with your national data protection supervisory authority.

---

## 10. Security

- All communication with our servers uses encrypted HTTPS/TLS connections.
- Passwords are stored only as cryptographic hashes, never in readable form.
- Database access is restricted by row-level security rules, so one user's
  records are not readable by another.

**An honest limitation you should know about:** to keep sign-up simple, we do
**not** verify phone numbers with an SMS code. This means a phone number in our
system is effectively a username, and we have no proof that the person who
registered it owns that number. Because of this, we also cannot offer automated
password recovery — password help goes through our support channel. Please do
not treat your Laffah account as a secure identity credential, and use a
password you do not reuse elsewhere.

---

## 11. Children

Laffah is not directed at children and is not intended for anyone under 16. We
do not knowingly collect data from children. If you believe a child has provided
us data, contact us and we will delete it.

---

## 12. International transfers

Our backend infrastructure is hosted with Supabase, and our route-optimisation
service and the mapping services listed in section 5 may process data on servers
outside your country, including outside Lebanon and the EEA. Where data of EEA
users is transferred outside the EEA, we rely on appropriate safeguards such as
the European Commission's Standard Contractual Clauses.

---

## 13. Changes to this policy

If we change this policy we will update the "Last updated" date above and
publish the new version at this address. Material changes will be announced in
the app.

---

## 14. Governing law

This policy is governed by the laws of **Lebanon**, and the courts of Beirut
have jurisdiction over any dispute arising from it.

If you are located in the EEA/EU, nothing in this policy removes the rights
guaranteed to you by the GDPR or by the mandatory law of your country of
residence.
