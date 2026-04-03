-- ============================================================
--  LUMIO — Schéma de base de données MySQL
--  Compatible MySQL 8.0+ / MariaDB 10.6+
--  Encodage : utf8mb4 (support emoji + caractères étendus)
--  Conformité RGAA : les données sont stockées avec accessibilité
-- ============================================================

CREATE DATABASE IF NOT EXISTS lumio
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE lumio;

-- ============================================================
--  UTILISATEURS
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
  id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  username        VARCHAR(30)  NOT NULL UNIQUE,
  email           VARCHAR(255) NOT NULL UNIQUE,
  password_hash   VARCHAR(255) NOT NULL,
  full_name       VARCHAR(100) DEFAULT NULL,
  bio             TEXT         DEFAULT NULL,
  avatar_url      VARCHAR(500) DEFAULT NULL,
  website         VARCHAR(255) DEFAULT NULL,
  is_private      TINYINT(1)   NOT NULL DEFAULT 0,
  is_verified     TINYINT(1)   NOT NULL DEFAULT 0,
  is_active       TINYINT(1)   NOT NULL DEFAULT 1,
  email_verified  TINYINT(1)   NOT NULL DEFAULT 0,
  -- Préférences accessibilité (sauvegardées en compte)
  pref_theme      ENUM('light','dark','auto')  DEFAULT 'auto',
  pref_dys        TINYINT(1)   NOT NULL DEFAULT 0,
  pref_daltonien  TINYINT(1)   NOT NULL DEFAULT 0,
  pref_font_size  TINYINT UNSIGNED NOT NULL DEFAULT 16,
  -- Timestamps
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  INDEX idx_username  (username),
  INDEX idx_email     (email),
  INDEX idx_active    (is_active),
  FULLTEXT ft_search  (username, full_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Comptes utilisateurs Lumio';

-- ============================================================
--  TOKENS DE RAFRAÎCHISSEMENT
-- ============================================================
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id    BIGINT UNSIGNED NOT NULL,
  token_hash VARCHAR(255) NOT NULL UNIQUE,
  expires_at DATETIME NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_token (token_hash),
  INDEX idx_user  (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
--  PUBLICATIONS (POSTS)
-- ============================================================
CREATE TABLE IF NOT EXISTS posts (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id     BIGINT UNSIGNED NOT NULL,
  image_url   VARCHAR(500) NOT NULL,
  caption     TEXT DEFAULT NULL,
  location    VARCHAR(100) DEFAULT NULL,
  -- Métadonnées image
  width       SMALLINT UNSIGNED DEFAULT NULL,
  height      SMALLINT UNSIGNED DEFAULT NULL,
  alt_text    VARCHAR(500) DEFAULT NULL  COMMENT 'Texte alternatif RGAA',
  -- Filtres / état
  filter_name VARCHAR(50) DEFAULT NULL,
  is_deleted  TINYINT(1) NOT NULL DEFAULT 0,
  -- Timestamps
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user        (user_id),
  INDEX idx_created_at  (created_at DESC),
  INDEX idx_not_deleted (is_deleted),
  FULLTEXT ft_caption   (caption, location)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Publications photo des utilisateurs';

-- ============================================================
--  MÉDIAS MULTIPLES PAR POST (carousel)
-- ============================================================
CREATE TABLE IF NOT EXISTS post_media (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  post_id     BIGINT UNSIGNED NOT NULL,
  media_url   VARCHAR(500) NOT NULL,
  alt_text    VARCHAR(500) DEFAULT NULL,
  position    TINYINT UNSIGNED NOT NULL DEFAULT 0,
  width       SMALLINT UNSIGNED DEFAULT NULL,
  height      SMALLINT UNSIGNED DEFAULT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  INDEX idx_post (post_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
--  HASHTAGS
-- ============================================================
CREATE TABLE IF NOT EXISTS hashtags (
  id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name       VARCHAR(100) NOT NULL UNIQUE,
  post_count INT UNSIGNED NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS post_hashtags (
  post_id    BIGINT UNSIGNED NOT NULL,
  hashtag_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (post_id, hashtag_id),
  FOREIGN KEY (post_id)    REFERENCES posts(id)    ON DELETE CASCADE,
  FOREIGN KEY (hashtag_id) REFERENCES hashtags(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================
--  MENTIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS mentions (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  post_id      BIGINT UNSIGNED NOT NULL,
  mentioned_id BIGINT UNSIGNED NOT NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_mention (post_id, mentioned_id),
  FOREIGN KEY (post_id)      REFERENCES posts(id) ON DELETE CASCADE,
  FOREIGN KEY (mentioned_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================
--  J'AIME (LIKES)
-- ============================================================
CREATE TABLE IF NOT EXISTS likes (
  id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  post_id    BIGINT UNSIGNED NOT NULL,
  user_id    BIGINT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  UNIQUE KEY uq_like (post_id, user_id),
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_likes (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
--  COMMENTAIRES
-- ============================================================
CREATE TABLE IF NOT EXISTS comments (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  post_id     BIGINT UNSIGNED NOT NULL,
  user_id     BIGINT UNSIGNED NOT NULL,
  parent_id   BIGINT UNSIGNED DEFAULT NULL  COMMENT 'Réponse à un commentaire',
  text        TEXT NOT NULL,
  is_deleted  TINYINT(1) NOT NULL DEFAULT 0,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  FOREIGN KEY (post_id)   REFERENCES posts(id)    ON DELETE CASCADE,
  FOREIGN KEY (user_id)   REFERENCES users(id)    ON DELETE CASCADE,
  FOREIGN KEY (parent_id) REFERENCES comments(id) ON DELETE SET NULL,
  INDEX idx_post    (post_id),
  INDEX idx_user    (user_id),
  INDEX idx_parent  (parent_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Likes sur commentaires
CREATE TABLE IF NOT EXISTS comment_likes (
  comment_id BIGINT UNSIGNED NOT NULL,
  user_id    BIGINT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (comment_id, user_id),
  FOREIGN KEY (comment_id) REFERENCES comments(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id)    REFERENCES users(id)    ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================
--  ABONNEMENTS (FOLLOWS)
-- ============================================================
CREATE TABLE IF NOT EXISTS follows (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  follower_id  BIGINT UNSIGNED NOT NULL,
  following_id BIGINT UNSIGNED NOT NULL,
  status       ENUM('pending','accepted') NOT NULL DEFAULT 'accepted',
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  UNIQUE KEY uq_follow (follower_id, following_id),
  FOREIGN KEY (follower_id)  REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (following_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_follower  (follower_id),
  INDEX idx_following (following_id),
  INDEX idx_status    (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
--  PUBLICATIONS ENREGISTRÉES
-- ============================================================
CREATE TABLE IF NOT EXISTS saved_posts (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id     BIGINT UNSIGNED NOT NULL,
  post_id     BIGINT UNSIGNED NOT NULL,
  collection  VARCHAR(100) DEFAULT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  UNIQUE KEY uq_saved (user_id, post_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  INDEX idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
--  STORIES
-- ============================================================
CREATE TABLE IF NOT EXISTS stories (
  id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id     BIGINT UNSIGNED NOT NULL,
  media_url   VARCHAR(500) NOT NULL,
  media_type  ENUM('image','video') NOT NULL DEFAULT 'image',
  alt_text    VARCHAR(500) DEFAULT NULL,
  duration    TINYINT UNSIGNED DEFAULT 5  COMMENT 'Durée en secondes',
  expires_at  DATETIME NOT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user       (user_id),
  INDEX idx_expires_at (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Vues de stories
CREATE TABLE IF NOT EXISTS story_views (
  story_id   BIGINT UNSIGNED NOT NULL,
  user_id    BIGINT UNSIGNED NOT NULL,
  viewed_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (story_id, user_id),
  FOREIGN KEY (story_id) REFERENCES stories(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id)  REFERENCES users(id)   ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================
--  MESSAGES DIRECTS
-- ============================================================
CREATE TABLE IF NOT EXISTS conversations (
  id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS conversation_members (
  conversation_id BIGINT UNSIGNED NOT NULL,
  user_id         BIGINT UNSIGNED NOT NULL,
  joined_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (conversation_id, user_id),
  FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id)         REFERENCES users(id)         ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS messages (
  id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  conversation_id BIGINT UNSIGNED NOT NULL,
  sender_id       BIGINT UNSIGNED NOT NULL,
  text            TEXT DEFAULT NULL,
  media_url       VARCHAR(500) DEFAULT NULL,
  is_read         TINYINT(1) NOT NULL DEFAULT 0,
  is_deleted      TINYINT(1) NOT NULL DEFAULT 0,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
  FOREIGN KEY (sender_id)       REFERENCES users(id)         ON DELETE CASCADE,
  INDEX idx_conversation (conversation_id),
  INDEX idx_created_at   (created_at DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
--  NOTIFICATIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS notifications (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id      BIGINT UNSIGNED NOT NULL  COMMENT 'Destinataire',
  actor_id     BIGINT UNSIGNED NOT NULL  COMMENT 'Qui a déclenché la notif',
  type         ENUM('like','comment','follow','mention','story_like','reply') NOT NULL,
  reference_id BIGINT UNSIGNED DEFAULT NULL  COMMENT 'ID du post/commentaire concerné',
  message      VARCHAR(255) DEFAULT NULL,
  is_read      TINYINT(1) NOT NULL DEFAULT 0,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (user_id)  REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (actor_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user      (user_id),
  INDEX idx_is_read   (is_read),
  INDEX idx_created   (created_at DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
--  SIGNALEMENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS reports (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  reporter_id  BIGINT UNSIGNED NOT NULL,
  target_type  ENUM('post','comment','user','story') NOT NULL,
  target_id    BIGINT UNSIGNED NOT NULL,
  reason       ENUM('spam','harassment','nudity','hate_speech','misinformation','other') NOT NULL,
  description  TEXT DEFAULT NULL,
  status       ENUM('pending','reviewed','resolved','dismissed') NOT NULL DEFAULT 'pending',
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_reporter (reporter_id),
  INDEX idx_status   (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
--  LOGS D'AUDIT (RGPD)
-- ============================================================
CREATE TABLE IF NOT EXISTS audit_logs (
  id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id    BIGINT UNSIGNED DEFAULT NULL,
  action     VARCHAR(100) NOT NULL,
  table_name VARCHAR(50)  DEFAULT NULL,
  record_id  BIGINT UNSIGNED DEFAULT NULL,
  ip_address VARCHAR(45)  DEFAULT NULL,
  user_agent TEXT         DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  INDEX idx_user      (user_id),
  INDEX idx_action    (action),
  INDEX idx_created   (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Journal RGPD des actions utilisateurs';

-- ============================================================
--  DONNÉES DE DÉMONSTRATION
-- ============================================================

-- Utilisateurs (mots de passe : "lumio2025!" hashés Argon2id)
INSERT INTO users (username, email, password_hash, full_name, bio, pref_theme) VALUES
('marie_lumio',  'marie@example.com',  '$argon2id$v=19$m=65536,t=4,p=1$placeholder', 'Marie Dupont',    'Photographe amateur 📸 | Lyon, France', 'auto'),
('lucas_photo',  'lucas@example.com',  '$argon2id$v=19$m=65536,t=4,p=1$placeholder', 'Lucas Martin',    'Capturer la lumière du quotidien ✨',      'dark'),
('sofia_art',    'sofia@example.com',  '$argon2id$v=19$m=65536,t=4,p=1$placeholder', 'Sofia Bernardi',  'Artiste peintre 🎨 | Milano → Paris',       'light'),
('theo_voyage',  'theo@example.com',   '$argon2id$v=19$m=65536,t=4,p=1$placeholder', 'Théo Leblanc',    '70 pays visités ✈️ | Toujours en route',   'auto'),
('amina_mode',   'amina@example.com',  '$argon2id$v=19$m=65536,t=4,p=1$placeholder', 'Amina Diallo',    'Styliste indépendante 👗 | Paris',          'light'),
('lea_nature',   'lea@example.com',    '$argon2id$v=19$m=65536,t=4,p=1$placeholder', 'Léa Fontaine',    'Nature & slow life 🌿 | Bretagne',         'auto');

-- Abonnements
INSERT INTO follows (follower_id, following_id) VALUES
(1,2),(1,3),(1,4),(2,1),(2,3),(3,1),(4,1),(4,2),(5,1),(5,3),(6,2),(6,4);

-- Publications de démo (URLs fictives — remplacer par vraies images)
INSERT INTO posts (user_id, image_url, caption, location, alt_text) VALUES
(2, '/uploads/demo1.jpg', 'La magie du lever de soleil sur Lyon 🌅 #lumio #photo',         'Lyon, France',      'Lever de soleil sur les toits de Lyon'),
(3, '/uploads/demo2.jpg', 'Mon atelier en pleine effusion créative 🎨 #art #couleurs',       'Paris, France',     'Atelier de peinture coloré'),
(4, '/uploads/demo3.jpg', 'Les rues de Kyoto sous les cerisiers 🌸 #voyage #japon',         'Kyoto, Japon',      'Allée de cerisiers en fleurs à Kyoto'),
(5, '/uploads/demo4.jpg', 'Nouvelle collection printemps 2025 👗 #mode #fashion',            'Paris, France',     'Tenue de mode printanière élégante'),
(6, '/uploads/demo5.jpg', 'La mer en janvier, rien ne vaut ça 🌊 #bretagne #nature',        'Brest, Bretagne',   'Vagues de l\'océan Atlantique en hiver'),
(2, '/uploads/demo6.jpg', 'Portraits urbains — série #3 🏙️ #streetphoto #lumio',            'Marseille, France', 'Portrait en noir et blanc dans une rue marseillaise');

-- Likes
INSERT INTO likes (post_id, user_id) VALUES
(1,1),(1,3),(1,4),(1,5),(2,1),(2,4),(3,1),(3,2),(4,1),(5,2),(5,3),(6,1),(6,4),(6,5);

-- Commentaires
INSERT INTO comments (post_id, user_id, text) VALUES
(1,1,'Magnifique ! Cette lumière est incroyable 😍'),
(1,3,'J''adore les tons dorés de ce lever de soleil !'),
(2,1,'Ton atelier est une vraie source d''inspiration 🎨'),
(3,1,'Je rêve de voir ça un jour en vrai... ✈️'),
(3,2,'Les cerisiers japonais, un autre niveau de beauté !'),
(4,6,'La couleur de cette robe est parfaite 🌸'),
(5,1,'La Bretagne en toutes saisons, c''est magique 💙');

-- Hashtags
INSERT INTO hashtags (name, post_count) VALUES
('lumio',9),('photo',4),('nature',3),('voyage',2),('art',2),('mode',1),('bretagne',1),('japon',1);

-- ============================================================
--  VUES UTILES
-- ============================================================

-- Vue fil d'actualité (optimisée)
CREATE OR REPLACE VIEW v_feed AS
SELECT
  p.id,
  p.user_id,
  p.image_url,
  p.caption,
  p.location,
  p.alt_text,
  p.created_at,
  u.username,
  u.full_name,
  u.avatar_url,
  u.is_verified,
  (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id) AS likes_count,
  (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id AND c.is_deleted = 0) AS comments_count
FROM posts p
JOIN users u ON u.id = p.user_id
WHERE p.is_deleted = 0
ORDER BY p.created_at DESC;

-- Vue suggestions (utilisateurs non suivis)
CREATE OR REPLACE VIEW v_suggestions AS
SELECT
  u.id, u.username, u.full_name, u.avatar_url, u.is_verified,
  (SELECT COUNT(*) FROM follows f WHERE f.following_id = u.id) AS followers_count
FROM users u
WHERE u.is_active = 1
ORDER BY followers_count DESC;

-- ============================================================
--  PROCÉDURES STOCKÉES
-- ============================================================

DELIMITER //

-- Nettoyer les stories expirées
CREATE PROCEDURE IF NOT EXISTS cleanup_stories()
BEGIN
  DELETE FROM stories WHERE expires_at < NOW();
END //

-- Obtenir le fil d'actualité d'un utilisateur
CREATE PROCEDURE IF NOT EXISTS get_user_feed(
  IN p_user_id BIGINT UNSIGNED,
  IN p_page    INT,
  IN p_per     INT
)
BEGIN
  DECLARE v_offset INT DEFAULT (p_page - 1) * p_per;
  SELECT p.*, u.username, u.avatar_url,
         (SELECT COUNT(*) FROM likes WHERE post_id = p.id) AS likes_count,
         (SELECT COUNT(*) FROM comments WHERE post_id = p.id) AS comments_count,
         EXISTS(SELECT 1 FROM likes WHERE post_id = p.id AND user_id = p_user_id) AS user_liked
  FROM posts p
  JOIN users u ON u.id = p.user_id
  WHERE p.is_deleted = 0
    AND (p.user_id IN (SELECT following_id FROM follows WHERE follower_id = p_user_id)
         OR p.user_id = p_user_id)
  ORDER BY p.created_at DESC
  LIMIT p_per OFFSET v_offset;
END //

DELIMITER ;

-- ============================================================
--  ÉVÉNEMENTS (nettoyage automatique)
-- ============================================================
SET GLOBAL event_scheduler = ON;

CREATE EVENT IF NOT EXISTS evt_cleanup_stories
ON SCHEDULE EVERY 1 HOUR
DO CALL cleanup_stories();

CREATE EVENT IF NOT EXISTS evt_cleanup_tokens
ON SCHEDULE EVERY 1 DAY
DO DELETE FROM refresh_tokens WHERE expires_at < NOW();
