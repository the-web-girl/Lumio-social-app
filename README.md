# 🌟 Lumio — Clone Instagram accessible

> *Partagez vos moments lumineux.* Réseau social de photos construit avec accessibilité et inclusion au cœur.

---

## 🎨 Design

**Palette** : Bleu `#2563EB` · Violet `#7C3AED` · Vert `#059669` · Blanc/Noir  
**Typographie** : Playfair Display (titres) + DM Sans (corps)  
**Responsive** : dès **320px** jusqu'à 4K

---

## ♿ Accessibilité (RGAA 4.1)

| Fonctionnalité | Implémentation |
|---|---|
| Skip link | Lien d'évitement vers `#main-content` |
| Structure sémantique | `<header>`, `<main>`, `<nav>`, `<aside>`, `<article>`, `<section>`, `<footer>` |
| Landmarks ARIA | `role="banner"`, `role="main"`, `role="navigation"`, `role="complementary"` |
| Images | `alt` systématique, `aria-label` sur placeholders emoji |
| Formulaires | `<label>` associés à chaque `<input>` via `for`/`id` |
| Focus visible | Ring CSS visible sur `:focus-visible` pour tous les éléments interactifs |
| Live regions | `aria-live="polite"` sur le feed, `aria-live="assertive"` sur les toasts |
| Dialogues modaux | `role="dialog"`, `aria-modal="true"`, focus piégé, fermeture Échap |
| Contrastes | AA minimum WCAG 2.1 (4.5:1 texte normal, 3:1 grands textes) |
| Navigation clavier | 100% opérable sans souris |
| Thème sombre | `prefers-color-scheme` + bouton manuel |
| Mouvement réduit | `prefers-reduced-motion` respecté |
| Impression | Styles `@media print` (masque nav/sidebar) |

### 🔧 Barre d'accessibilité

Bouton fixe sur le côté droit :

- **🌙 Thème sombre/clair** — respecte aussi la préférence système
- **𝔸 Mode DYS** — police adaptée, espacement lettres/mots augmenté, interligne 1.8
- **👁 Mode daltonien** — palette Okabe-Ito (bleu `#0072B2`, orange `#E69F00`, rose `#CC79A7`)
- **A+ / A-** — zoom texte de 12px à 24px (par pas de 2px)
- **↺ Réinitialiser** — taille de texte par défaut
- Préférences **sauvegardées** dans `localStorage`

---

## 🚀 Installation

### Prérequis

- **PHP** 8.1+
- **MySQL** 8.0+ ou **MariaDB** 10.6+
- **Serveur web** : Apache / Nginx
- **Composer** (optionnel, pour extensions futures)

### Étapes

```bash
# 1. Cloner / déposer les fichiers
mkdir lumio && cd lumio
# Copier index.html, api.php, schema.sql dans ce dossier

# 2. Créer la base de données
mysql -u root -p < schema.sql

# 3. Configurer api.php
nano api.php
# Modifier : DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASS, JWT_SECRET

# 4. Créer le dossier uploads
mkdir uploads && chmod 755 uploads

# 5. Configurer Apache (virtual host)
```

**Apache `.htaccess`** :
```apache
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^api/(.*)$ api.php [QSA,L]
```

**Nginx** :
```nginx
location /api/ {
    try_files $uri $uri/ /api.php?$query_string;
    fastcgi_pass unix:/run/php/php8.1-fpm.sock;
    fastcgi_param SCRIPT_FILENAME $document_root/api.php;
    include fastcgi_params;
}
```

---

## 📡 API REST

Base URL : `https://votre-domaine.com/api`

### Authentification

```http
POST /auth/register
Content-Type: application/json

{
  "username": "marie_lumio",
  "email": "marie@example.com",
  "password": "motdepasse123"
}
```

```http
POST /auth/login
→ { "token": "eyJ...", "user_id": 1, "username": "marie_lumio" }
```

Toutes les routes protégées nécessitent :
```http
Authorization: Bearer <token>
```

### Endpoints principaux

| Méthode | Route | Description |
|---------|-------|-------------|
| `GET` | `/posts/feed?page=1` | Fil d'actualité |
| `POST` | `/posts` | Publier (multipart/form-data) |
| `GET` | `/posts/:id` | Détail d'une publication |
| `DELETE` | `/posts/:id` | Supprimer sa publication |
| `POST` | `/posts/:id/like` | Aimer / Ne plus aimer |
| `GET` | `/posts/:id/comments` | Commentaires |
| `POST` | `/posts/:id/comments` | Commenter |
| `DELETE` | `/comments/:id` | Supprimer un commentaire |
| `GET` | `/users/me` | Mon profil |
| `PUT` | `/users/me` | Modifier mon profil |
| `GET` | `/users/:username` | Profil utilisateur |
| `GET` | `/users/search?q=…` | Recherche |
| `POST` | `/users/:id/follow` | Suivre / Ne plus suivre |
| `GET` | `/stories` | Stories actives |
| `POST` | `/stories` | Publier une story |

### Exemple d'appel JavaScript

```javascript
// Connexion
const res = await fetch('/api/auth/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email: 'marie@example.com', password: 'lumio2025!' })
});
const { token } = await res.json();

// Récupérer le fil
const feed = await fetch('/api/posts/feed', {
  headers: { Authorization: `Bearer ${token}` }
});
const posts = await feed.json();
```

---

## 🗄️ Schéma de base de données

```
users ─────────────────── posts ─── post_media
  │                          │
  ├─ follows                 ├─ likes
  ├─ refresh_tokens          ├─ comments ─── comment_likes
  └─ notifications           ├─ saved_posts
                             ├─ post_hashtags ─── hashtags
stories ─── story_views      └─ mentions
conversations ─── conversation_members ─── messages
reports
audit_logs
```

---

## 🔒 Sécurité

- **Mots de passe** : Argon2id (PHP `PASSWORD_ARGON2ID`)
- **JWT** : HMAC-SHA256, expiration 7 jours, refresh token en base
- **Requêtes SQL** : PDO avec requêtes préparées (anti-injection)
- **Uploads** : validation MIME + taille, nom randomisé
- **Headers** : `X-Content-Type-Options`, `X-Frame-Options`, `X-XSS-Protection`, `Referrer-Policy`
- **CORS** : configurable selon environnement
- **Rate limiting** : à implémenter avec Redis ou table MySQL

---

## 🌍 RGPD

- Table `audit_logs` pour traçabilité
- Champ `is_active` pour désactivation de compte sans suppression immédiate
- Données personnelles minimisées
- Prévoir export des données utilisateur (droit à la portabilité)

---

## 📱 Fonctionnalités

### Frontend (index.html)
- ✅ Feed avec infinite scroll
- ✅ Stories avec barre de progression animée
- ✅ Double-tap pour liker
- ✅ Aimer / Enregistrer / Partager
- ✅ Commentaires
- ✅ Publication avec drag & drop
- ✅ Recherche
- ✅ Navigation mobile bottom bar
- ✅ Suggestions d'utilisateurs
- ✅ Thème sombre/clair
- ✅ Mode DYS, daltonien, zoom

### Backend (api.php + schema.sql)
- ✅ Auth JWT sécurisée
- ✅ CRUD publications
- ✅ Système de like/unlike
- ✅ Commentaires + réponses
- ✅ Abonnements
- ✅ Stories (24h)
- ✅ Messages directs (schéma)
- ✅ Notifications (schéma)
- ✅ Signalements (schéma)
- ✅ Vues SQL optimisées
- ✅ Procédures stockées + événements automatiques

---

## 🤝 Contribuer

1. Fork le projet
2. Créer une branche : `git checkout -b feature/ma-fonctionnalite`
3. Commit : `git commit -m 'feat: ajouter X'`
4. Push : `git push origin feature/ma-fonctionnalite`
5. Ouvrir une Pull Request

---

## 📄 Licence

MIT — Libre d'utilisation, modification et distribution.

---

*Lumio — Fait avec 💜 en France · Conformité RGAA 4.1*
