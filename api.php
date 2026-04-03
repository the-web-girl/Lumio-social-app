<?php
/**
 * Lumio — API Backend PHP
 * Compatible PHP 8.1+
 * RGAA-compliant REST API
 */

declare(strict_types=1);

// ─── CONFIGURATION ────────────────────────────────────────────
define('DB_HOST', 'localhost');
define('DB_PORT', '3306');
define('DB_NAME', 'lumio');
define('DB_USER', 'root');
define('DB_PASS', '');
define('DB_CHARSET', 'utf8mb4');

define('JWT_SECRET', 'CHANGE_ME_lumio_secret_2025');
define('JWT_EXPIRY', 3600 * 24 * 7); // 7 jours
define('UPLOAD_DIR', __DIR__ . '/uploads/');
define('MAX_FILE_SIZE', 10 * 1024 * 1024); // 10 Mo
define('ALLOWED_MIME', ['image/jpeg', 'image/png', 'image/gif', 'image/webp']);
define('API_VERSION', '1.0.0');

// ─── CORS & HEADERS ────────────────────────────────────────────
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('X-XSS-Protection: 1; mode=block');
header('Referrer-Policy: strict-origin-when-cross-origin');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

// ─── DATABASE ──────────────────────────────────────────────────
class Database {
    private static ?PDO $instance = null;

    public static function get(): PDO {
        if (self::$instance === null) {
            $dsn = sprintf(
                'mysql:host=%s;port=%s;dbname=%s;charset=%s',
                DB_HOST, DB_PORT, DB_NAME, DB_CHARSET
            );
            self::$instance = new PDO($dsn, DB_USER, DB_PASS, [
                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES   => false,
                PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci",
            ]);
        }
        return self::$instance;
    }
}

// ─── JWT ───────────────────────────────────────────────────────
class JWT {
    public static function encode(array $payload): string {
        $header  = self::b64url(json_encode(['alg' => 'HS256', 'typ' => 'JWT']));
        $payload = self::b64url(json_encode($payload + ['iat' => time(), 'exp' => time() + JWT_EXPIRY]));
        $sig     = self::b64url(hash_hmac('sha256', "$header.$payload", JWT_SECRET, true));
        return "$header.$payload.$sig";
    }

    public static function decode(string $token): ?array {
        $parts = explode('.', $token);
        if (count($parts) !== 3) return null;
        [$h, $p, $s] = $parts;
        $expected = self::b64url(hash_hmac('sha256', "$h.$p", JWT_SECRET, true));
        if (!hash_equals($expected, $s)) return null;
        $payload = json_decode(base64_decode(strtr($p, '-_', '+/')), true);
        if (!$payload || $payload['exp'] < time()) return null;
        return $payload;
    }

    private static function b64url(string $data): string {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }
}

// ─── ROUTER ────────────────────────────────────────────────────
class Router {
    private array $routes = [];

    public function add(string $method, string $pattern, callable $handler, bool $auth = false): void {
        $this->routes[] = compact('method', 'pattern', 'handler', 'auth');
    }

    public function dispatch(): void {
        $method = $_SERVER['REQUEST_METHOD'];
        $uri    = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
        $uri    = rtrim(str_replace('/api', '', $uri), '/') ?: '/';

        foreach ($this->routes as $route) {
            if ($route['method'] !== $method) continue;
            $regex   = '#^' . preg_replace('/:([a-z_]+)/', '(?P<$1>[^/]+)', $route['pattern']) . '$#';
            if (!preg_match($regex, $uri, $matches)) continue;

            $params = array_filter($matches, 'is_string', ARRAY_FILTER_USE_KEY);
            $userId = null;

            if ($route['auth']) {
                $token = self::getBearerToken();
                $payload = $token ? JWT::decode($token) : null;
                if (!$payload) { self::json(['error' => 'Non authentifié'], 401); return; }
                $userId = (int)$payload['sub'];
            }

            try {
                ($route['handler'])($params, $userId);
            } catch (PDOException $e) {
                error_log('DB Error: ' . $e->getMessage());
                self::json(['error' => 'Erreur serveur'], 500);
            } catch (Throwable $e) {
                error_log('Error: ' . $e->getMessage());
                self::json(['error' => 'Erreur interne'], 500);
            }
            return;
        }

        self::json(['error' => 'Route introuvable'], 404);
    }

    public static function json(array $data, int $code = 200): void {
        http_response_code($code);
        echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
        exit;
    }

    public static function body(): array {
        $raw = file_get_contents('php://input');
        return json_decode($raw, true) ?? [];
    }

    private static function getBearerToken(): ?string {
        $h = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
        if (preg_match('/Bearer\s(.+)/', $h, $m)) return $m[1];
        return null;
    }
}

// ─── MODELS ────────────────────────────────────────────────────

class UserModel {
    public static function create(string $username, string $email, string $password): int {
        $db   = Database::get();
        $hash = password_hash($password, PASSWORD_ARGON2ID);
        $stmt = $db->prepare('INSERT INTO users (username, email, password_hash, created_at) VALUES (?,?,?,NOW())');
        $stmt->execute([$username, $email, $hash]);
        return (int)$db->lastInsertId();
    }

    public static function findByEmail(string $email): ?array {
        $stmt = Database::get()->prepare('SELECT * FROM users WHERE email = ? LIMIT 1');
        $stmt->execute([$email]);
        return $stmt->fetch() ?: null;
    }

    public static function findById(int $id): ?array {
        $stmt = Database::get()->prepare(
            'SELECT id, username, full_name, bio, avatar_url, website,
                    (SELECT COUNT(*) FROM follows WHERE following_id = u.id) AS followers_count,
                    (SELECT COUNT(*) FROM follows WHERE follower_id  = u.id) AS following_count,
                    (SELECT COUNT(*) FROM posts WHERE user_id = u.id) AS posts_count,
                    created_at
             FROM users u WHERE id = ? LIMIT 1'
        );
        $stmt->execute([$id]);
        return $stmt->fetch() ?: null;
    }

    public static function search(string $q, int $limit = 20): array {
        $stmt = Database::get()->prepare(
            'SELECT id, username, full_name, avatar_url FROM users
             WHERE username LIKE ? OR full_name LIKE ?
             LIMIT ?'
        );
        $like = "%$q%";
        $stmt->execute([$like, $like, $limit]);
        return $stmt->fetchAll();
    }

    public static function update(int $id, array $data): void {
        $fields = array_intersect_key($data, array_flip(['full_name', 'bio', 'website', 'avatar_url']));
        if (empty($fields)) return;
        $set  = implode(', ', array_map(fn($k) => "$k = ?", array_keys($fields)));
        $stmt = Database::get()->prepare("UPDATE users SET $set, updated_at = NOW() WHERE id = ?");
        $stmt->execute([...array_values($fields), $id]);
    }
}

class PostModel {
    public static function create(int $userId, string $imageUrl, string $caption = '', string $location = ''): int {
        $stmt = Database::get()->prepare(
            'INSERT INTO posts (user_id, image_url, caption, location, created_at) VALUES (?,?,?,?,NOW())'
        );
        $stmt->execute([$userId, $imageUrl, $caption, $location]);
        return (int)Database::get()->lastInsertId();
    }

    public static function getFeed(int $userId, int $page = 1, int $per = 10): array {
        $offset = ($page - 1) * $per;
        $stmt   = Database::get()->prepare(
            'SELECT p.*, u.username, u.avatar_url,
                    (SELECT COUNT(*) FROM likes WHERE post_id = p.id) AS likes_count,
                    (SELECT COUNT(*) FROM comments WHERE post_id = p.id) AS comments_count,
                    EXISTS(SELECT 1 FROM likes WHERE post_id = p.id AND user_id = :uid) AS user_liked,
                    EXISTS(SELECT 1 FROM saved_posts WHERE post_id = p.id AND user_id = :uid2) AS user_saved
             FROM posts p
             JOIN users u ON u.id = p.user_id
             WHERE p.user_id IN (SELECT following_id FROM follows WHERE follower_id = :uid3)
                OR p.user_id = :uid4
             ORDER BY p.created_at DESC
             LIMIT :lim OFFSET :off'
        );
        $stmt->bindValue(':uid',  $userId, PDO::PARAM_INT);
        $stmt->bindValue(':uid2', $userId, PDO::PARAM_INT);
        $stmt->bindValue(':uid3', $userId, PDO::PARAM_INT);
        $stmt->bindValue(':uid4', $userId, PDO::PARAM_INT);
        $stmt->bindValue(':lim',  $per,    PDO::PARAM_INT);
        $stmt->bindValue(':off',  $offset, PDO::PARAM_INT);
        $stmt->execute();
        return $stmt->fetchAll();
    }

    public static function getById(int $postId, int $userId): ?array {
        $stmt = Database::get()->prepare(
            'SELECT p.*, u.username, u.avatar_url,
                    (SELECT COUNT(*) FROM likes WHERE post_id = p.id) AS likes_count,
                    EXISTS(SELECT 1 FROM likes WHERE post_id = p.id AND user_id = ?) AS user_liked
             FROM posts p JOIN users u ON u.id = p.user_id
             WHERE p.id = ? LIMIT 1'
        );
        $stmt->execute([$userId, $postId]);
        return $stmt->fetch() ?: null;
    }

    public static function delete(int $postId, int $userId): bool {
        $stmt = Database::get()->prepare('DELETE FROM posts WHERE id = ? AND user_id = ?');
        $stmt->execute([$postId, $userId]);
        return $stmt->rowCount() > 0;
    }
}

class LikeModel {
    public static function toggle(int $postId, int $userId): array {
        $db   = Database::get();
        $stmt = $db->prepare('SELECT id FROM likes WHERE post_id = ? AND user_id = ?');
        $stmt->execute([$postId, $userId]);
        if ($stmt->fetch()) {
            $db->prepare('DELETE FROM likes WHERE post_id = ? AND user_id = ?')->execute([$postId, $userId]);
            $liked = false;
        } else {
            $db->prepare('INSERT INTO likes (post_id, user_id, created_at) VALUES (?,?,NOW())')->execute([$postId, $userId]);
            $liked = true;
        }
        $count = (int)$db->query("SELECT COUNT(*) FROM likes WHERE post_id = $postId")->fetchColumn();
        return ['liked' => $liked, 'count' => $count];
    }
}

class CommentModel {
    public static function add(int $postId, int $userId, string $text): int {
        $text = mb_substr(trim($text), 0, 2200);
        $stmt = Database::get()->prepare(
            'INSERT INTO comments (post_id, user_id, text, created_at) VALUES (?,?,?,NOW())'
        );
        $stmt->execute([$postId, $userId, $text]);
        return (int)Database::get()->lastInsertId();
    }

    public static function getByPost(int $postId, int $page = 1): array {
        $offset = ($page - 1) * 20;
        $stmt   = Database::get()->prepare(
            'SELECT c.*, u.username, u.avatar_url
             FROM comments c JOIN users u ON u.id = c.user_id
             WHERE c.post_id = ?
             ORDER BY c.created_at ASC
             LIMIT 20 OFFSET ?'
        );
        $stmt->execute([$postId, $offset]);
        return $stmt->fetchAll();
    }

    public static function delete(int $commentId, int $userId): bool {
        $stmt = Database::get()->prepare('DELETE FROM comments WHERE id = ? AND user_id = ?');
        $stmt->execute([$commentId, $userId]);
        return $stmt->rowCount() > 0;
    }
}

class FollowModel {
    public static function toggle(int $followerId, int $followingId): array {
        if ($followerId === $followingId) return ['error' => 'Impossible de se suivre soi-même'];
        $db   = Database::get();
        $stmt = $db->prepare('SELECT id FROM follows WHERE follower_id = ? AND following_id = ?');
        $stmt->execute([$followerId, $followingId]);
        if ($stmt->fetch()) {
            $db->prepare('DELETE FROM follows WHERE follower_id = ? AND following_id = ?')->execute([$followerId, $followingId]);
            $following = false;
        } else {
            $db->prepare('INSERT INTO follows (follower_id, following_id, created_at) VALUES (?,?,NOW())')->execute([$followerId, $followingId]);
            $following = true;
        }
        return ['following' => $following];
    }
}

class StoryModel {
    public static function create(int $userId, string $mediaUrl): int {
        $stmt = Database::get()->prepare(
            'INSERT INTO stories (user_id, media_url, expires_at, created_at) VALUES (?,?,DATE_ADD(NOW(), INTERVAL 24 HOUR),NOW())'
        );
        $stmt->execute([$userId, $mediaUrl]);
        return (int)Database::get()->lastInsertId();
    }

    public static function getActive(int $userId): array {
        $stmt = Database::get()->prepare(
            'SELECT s.*, u.username, u.avatar_url
             FROM stories s JOIN users u ON u.id = s.user_id
             WHERE s.expires_at > NOW()
               AND (s.user_id IN (SELECT following_id FROM follows WHERE follower_id = ?) OR s.user_id = ?)
             ORDER BY s.created_at DESC'
        );
        $stmt->execute([$userId, $userId]);
        return $stmt->fetchAll();
    }
}

// ─── UPLOAD HELPER ─────────────────────────────────────────────
function handleUpload(string $field = 'image'): string {
    if (!isset($_FILES[$field]) || $_FILES[$field]['error'] !== UPLOAD_ERR_OK) {
        Router::json(['error' => 'Fichier manquant ou erreur upload'], 400);
    }
    $file = $_FILES[$field];
    if ($file['size'] > MAX_FILE_SIZE) Router::json(['error' => 'Fichier trop volumineux (max 10 Mo)'], 413);
    $mime = mime_content_type($file['tmp_name']);
    if (!in_array($mime, ALLOWED_MIME, true)) Router::json(['error' => 'Type de fichier non autorisé'], 415);

    if (!is_dir(UPLOAD_DIR)) mkdir(UPLOAD_DIR, 0755, true);
    $ext      = pathinfo($file['name'], PATHINFO_EXTENSION);
    $filename = bin2hex(random_bytes(16)) . '.' . strtolower($ext);
    $dest     = UPLOAD_DIR . $filename;
    if (!move_uploaded_file($file['tmp_name'], $dest)) Router::json(['error' => 'Erreur lors de la sauvegarde'], 500);

    return '/uploads/' . $filename;
}

// ─── ROUTES ────────────────────────────────────────────────────
$r = new Router();

/* ── Health ── */
$r->add('GET', '/', fn() => Router::json([
    'app'     => 'Lumio API',
    'version' => API_VERSION,
    'status'  => 'ok',
    'rgaa'    => '4.1',
]));

/* ── Auth ── */
$r->add('POST', '/auth/register', function() {
    $b = Router::body();
    $username = trim($b['username'] ?? '');
    $email    = filter_var($b['email'] ?? '', FILTER_VALIDATE_EMAIL);
    $password = $b['password'] ?? '';

    if (!$username || !$email || strlen($password) < 8) {
        Router::json(['error' => 'Données invalides. Mot de passe ≥ 8 caractères.'], 422);
    }
    if (preg_match('/[^a-z0-9_.]/i', $username) || strlen($username) > 30) {
        Router::json(['error' => 'Nom d\'utilisateur invalide (lettres, chiffres, . _)'], 422);
    }

    $db = Database::get();
    if ($db->prepare('SELECT id FROM users WHERE email = ? OR username = ?')->execute([$email, $username])) {
        $exists = $db->prepare('SELECT id FROM users WHERE email = ? OR username = ?');
        $exists->execute([$email, $username]);
        if ($exists->fetch()) Router::json(['error' => 'Email ou pseudo déjà utilisé'], 409);
    }

    $id    = UserModel::create($username, $email, $password);
    $token = JWT::encode(['sub' => $id, 'username' => $username]);
    Router::json(['token' => $token, 'user_id' => $id, 'username' => $username], 201);
});

$r->add('POST', '/auth/login', function() {
    $b     = Router::body();
    $email = filter_var($b['email'] ?? '', FILTER_VALIDATE_EMAIL);
    $pass  = $b['password'] ?? '';

    if (!$email || !$pass) Router::json(['error' => 'Email et mot de passe requis'], 422);

    $user = UserModel::findByEmail($email);
    if (!$user || !password_verify($pass, $user['password_hash'])) {
        Router::json(['error' => 'Identifiants incorrects'], 401);
    }

    // Rehash si nécessaire
    if (password_needs_rehash($user['password_hash'], PASSWORD_ARGON2ID)) {
        $newHash = password_hash($pass, PASSWORD_ARGON2ID);
        Database::get()->prepare('UPDATE users SET password_hash = ? WHERE id = ?')->execute([$newHash, $user['id']]);
    }

    $token = JWT::encode(['sub' => $user['id'], 'username' => $user['username']]);
    Router::json(['token' => $token, 'user_id' => $user['id'], 'username' => $user['username']]);
});

/* ── Users ── */
$r->add('GET', '/users/me', function($p, $uid) {
    $user = UserModel::findById($uid);
    if (!$user) Router::json(['error' => 'Utilisateur introuvable'], 404);
    Router::json($user);
}, auth: true);

$r->add('PUT', '/users/me', function($p, $uid) {
    $b = Router::body();
    UserModel::update($uid, $b);
    Router::json(['success' => true]);
}, auth: true);

$r->add('GET', '/users/:username', function($p, $uid) {
    $stmt = Database::get()->prepare('SELECT id FROM users WHERE username = ?');
    $stmt->execute([$p['username']]);
    $row = $stmt->fetch();
    if (!$row) Router::json(['error' => 'Utilisateur introuvable'], 404);
    Router::json(UserModel::findById($row['id']));
}, auth: true);

$r->add('GET', '/users/search', function($p, $uid) {
    $q = $_GET['q'] ?? '';
    if (strlen($q) < 1) Router::json([]);
    Router::json(UserModel::search($q));
}, auth: true);

/* ── Follow ── */
$r->add('POST', '/users/:id/follow', function($p, $uid) {
    Router::json(FollowModel::toggle($uid, (int)$p['id']));
}, auth: true);

/* ── Posts ── */
$r->add('GET', '/posts/feed', function($p, $uid) {
    $page = max(1, (int)($_GET['page'] ?? 1));
    Router::json(PostModel::getFeed($uid, $page));
}, auth: true);

$r->add('POST', '/posts', function($p, $uid) {
    $imageUrl = handleUpload('image');
    $caption  = mb_substr(trim($_POST['caption'] ?? ''), 0, 2200);
    $location = mb_substr(trim($_POST['location'] ?? ''), 0, 100);
    $id       = PostModel::create($uid, $imageUrl, $caption, $location);
    Router::json(['id' => $id, 'image_url' => $imageUrl], 201);
}, auth: true);

$r->add('GET', '/posts/:id', function($p, $uid) {
    $post = PostModel::getById((int)$p['id'], $uid);
    if (!$post) Router::json(['error' => 'Publication introuvable'], 404);
    Router::json($post);
}, auth: true);

$r->add('DELETE', '/posts/:id', function($p, $uid) {
    if (!PostModel::delete((int)$p['id'], $uid)) Router::json(['error' => 'Impossible de supprimer'], 403);
    Router::json(['success' => true]);
}, auth: true);

/* ── Likes ── */
$r->add('POST', '/posts/:id/like', function($p, $uid) {
    Router::json(LikeModel::toggle((int)$p['id'], $uid));
}, auth: true);

/* ── Comments ── */
$r->add('GET', '/posts/:id/comments', function($p, $uid) {
    $page = max(1, (int)($_GET['page'] ?? 1));
    Router::json(CommentModel::getByPost((int)$p['id'], $page));
}, auth: true);

$r->add('POST', '/posts/:id/comments', function($p, $uid) {
    $b    = Router::body();
    $text = trim($b['text'] ?? '');
    if (!$text) Router::json(['error' => 'Commentaire vide'], 422);
    $id   = CommentModel::add((int)$p['id'], $uid, $text);
    Router::json(['id' => $id], 201);
}, auth: true);

$r->add('DELETE', '/comments/:id', function($p, $uid) {
    if (!CommentModel::delete((int)$p['id'], $uid)) Router::json(['error' => 'Impossible de supprimer'], 403);
    Router::json(['success' => true]);
}, auth: true);

/* ── Stories ── */
$r->add('GET', '/stories', function($p, $uid) {
    Router::json(StoryModel::getActive($uid));
}, auth: true);

$r->add('POST', '/stories', function($p, $uid) {
    $mediaUrl = handleUpload('media');
    $id       = StoryModel::create($uid, $mediaUrl);
    Router::json(['id' => $id, 'media_url' => $mediaUrl], 201);
}, auth: true);

/* ── Dispatch ── */
$r->dispatch();
