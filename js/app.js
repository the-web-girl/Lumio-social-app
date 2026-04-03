'use strict';

/* ================================
   DATA — fake users & posts
================================ */
const USERS = [
  { id:1, name:'lucas_photo', full:'Lucas Martin', emoji:'📸', color:'#2563EB' },
  { id:2, name:'sofia_art',   full:'Sofia Bernardi', emoji:'🎨', color:'#7C3AED' },
  { id:3, name:'theo_voyage', full:'Théo Leblanc', emoji:'✈️', color:'#059669' },
  { id:4, name:'amina_mode',  full:'Amina Diallo', emoji:'👗', color:'#D97706' },
  { id:5, name:'pierre_cafe', full:'Pierre Moreau', emoji:'☕', color:'#DC2626' },
  { id:6, name:'lea_nature',  full:'Léa Fontaine', emoji:'🌿', color:'#065F46' },
];

const EMOJIS = ['🌅','🌊','🏔️','🌸','🍕','🎵','🌙','⚡','🦋','🌺','🎭','🏖️','🌈','🍃','✨'];
const CAPTIONS = [
  'Un moment de pur bonheur 🌟 #lumio #moments',
  'La lumière du matin… rien de tel pour commencer la journée ☀️',
  'Chaque photo raconte une histoire. Quelle est la vôtre ? 💫',
  'Perdu dans les couleurs de l\'automne 🍂 #nature #beauté',
  'Pause bien méritée ☕ #lifestyle #lumio',
  'L\'art de voir la beauté dans le quotidien 🎨',
  'Horizons infinis et rêves sans limites ✈️ #voyage',
  'La nature nous offre les plus beaux filtres 🌿',
];
const TIMES = ['Il y a 2 min','Il y a 15 min','Il y a 1h','Il y a 3h','Il y a 6h','Il y a 12h','Il y a 1j','Il y a 2j'];
const LOCATIONS = ['Paris, France','Lyon, France','Marseille, France','Nice, Côte d\'Azur','Bordeaux, France','','Montpellier','Strasbourg'];

let posts = [];
let storyIndex = 0;
let storyTimer = null;
let fontSize = 16;

/* ================================
   GENERATE POSTS
================================ */
function generatePost(id) {
  const user = USERS[Math.floor(Math.random() * USERS.length)];
  const likes = Math.floor(Math.random() * 9000) + 100;
  const emoji = EMOJIS[Math.floor(Math.random() * EMOJIS.length)];
  const caption = CAPTIONS[Math.floor(Math.random() * CAPTIONS.length)];
  const time = TIMES[Math.floor(Math.random() * TIMES.length)];
  const location = LOCATIONS[Math.floor(Math.random() * LOCATIONS.length)];
  return { id, user, likes, emoji, caption, time, location, liked: false, saved: false, comments: [] };
}

/* ================================
   RENDER STORIES
================================ */
function renderStories() {
  const container = document.getElementById('storiesList');
  USERS.forEach((u, i) => {
    const div = document.createElement('div');
    div.className = 'story-item';
    div.setAttribute('role', 'listitem');
    div.innerHTML = `
      <button class="story-ring ${i > 2 ? 'seen' : ''}"
              aria-label="Voir la story de ${u.full}"
              onclick="openStory(${i})">
        <div style="width:100%;height:100%;border-radius:50%;background:${u.color};display:flex;align-items:center;justify-content:center;font-size:24px;border:2px solid var(--surface)">${u.emoji}</div>
      </button>
      <span class="story-name">${u.name}</span>
    `;
    container.appendChild(div);
  });
}

/* ================================
   RENDER SUGGESTIONS
================================ */
function renderSuggestions() {
  const ul = document.getElementById('suggestList');
  USERS.slice(0, 5).forEach(u => {
    const li = document.createElement('li');
    li.className = 'suggest-item';
    li.innerHTML = `
      <div class="suggest-avatar" style="width:40px;height:40px;border-radius:50%;background:${u.color};display:flex;align-items:center;justify-content:center;font-size:18px" aria-hidden="true">${u.emoji}</div>
      <div class="suggest-info">
        <div class="suggest-name">${u.name}</div>
        <div class="suggest-reason">Suggéré pour vous</div>
      </div>
      <button class="follow-btn" onclick="toggleFollow(this, '${u.full}')" aria-label="Suivre ${u.full}">Suivre</button>
    `;
    ul.appendChild(li);
  });
}

/* ================================
   RENDER POST
================================ */
function renderPost(post) {
  const article = document.createElement('article');
  article.className = 'post';
  article.id = `post-${post.id}`;
  article.setAttribute('aria-label', `Publication de ${post.user.name}`);

  article.innerHTML = `
    <div class="post-header">
      <div class="post-avatar" aria-hidden="true">
        <div style="width:100%;height:100%;border-radius:50%;background:${post.user.color};display:flex;align-items:center;justify-content:center;font-size:18px">${post.user.emoji}</div>
      </div>
      <div class="post-user">
        <div class="post-username">
          <a href="#" aria-label="Voir le profil de ${post.user.name}">${post.user.name}</a>
        </div>
        ${post.location ? `<div class="post-location">${post.location}</div>` : ''}
      </div>
      <button class="post-more action-btn" style="font-size:18px" aria-label="Plus d'options pour cette publication" aria-haspopup="true">⋯</button>
    </div>

    <div class="post-media">
      <div class="post-img-placeholder" role="img" aria-label="Image de ${post.user.name} : ${post.caption.substring(0,50)}…"
           ondblclick="handleDoubleLike(${post.id})" style="cursor:pointer">
        ${post.emoji}
      </div>
      <div class="like-overlay" id="overlay-${post.id}" aria-hidden="true"><span>❤️</span></div>
    </div>

    <div class="post-actions" role="group" aria-label="Actions sur la publication">
      <button class="action-btn" id="like-${post.id}"
              onclick="toggleLike(${post.id})"
              aria-label="${post.liked ? 'Ne plus aimer' : 'Aimer'} cette publication"
              aria-pressed="${post.liked}">
        <span class="action-icon" aria-hidden="true">${post.liked ? '❤️' : '🤍'}</span>
      </button>
      <button class="action-btn" aria-label="Commenter cette publication">
        <span aria-hidden="true">💬</span>
      </button>
      <button class="action-btn" onclick="sharePost(${post.id})" aria-label="Partager cette publication">
        <span aria-hidden="true">📤</span>
      </button>
      <button class="action-btn post-save" id="save-${post.id}"
              onclick="toggleSave(${post.id})"
              aria-label="${post.saved ? 'Retirer des enregistrements' : 'Enregistrer'}"
              aria-pressed="${post.saved}">
        <span aria-hidden="true">${post.saved ? '🔖' : '📋'}</span>
      </button>
    </div>

    <p class="post-likes" aria-live="polite">
      <span id="likes-count-${post.id}">${formatLikes(post.likes)}</span> J'aime
    </p>

    <p class="post-caption">
      <span class="caption-user">${post.user.name}</span>${post.caption}
    </p>

    ${post.comments.length > 0 ? `
    <div class="post-comments">
      <button class="comments-link" aria-label="Voir les ${post.comments.length} commentaire(s)">
        Voir les ${post.comments.length} commentaire(s)
      </button>
    </div>` : ''}

    <p class="post-time"><time>${post.time}</time></p>

    <div class="post-comment-form" role="form" aria-label="Ajouter un commentaire">
      <label for="comment-${post.id}" class="sr-only" style="position:absolute;clip:rect(0,0,0,0)">Votre commentaire</label>
      <input type="text" class="comment-input" id="comment-${post.id}"
             placeholder="Ajoutez un commentaire…"
             aria-label="Écrire un commentaire pour la publication de ${post.user.name}"
             oninput="updateCommentBtn(${post.id}, this.value)"
             onkeydown="if(event.key==='Enter')submitComment(${post.id})">
      <button class="comment-submit" id="comment-btn-${post.id}"
              onclick="submitComment(${post.id})"
              aria-label="Publier le commentaire" disabled>
        Publier
      </button>
    </div>
  `;
  return article;
}

/* ================================
   INFINITE SCROLL FEED
================================ */
let page = 0;
let loading = false;

function loadPosts() {
  if (loading) return;
  loading = true;
  setTimeout(() => {
    const feed = document.getElementById('feedPosts');
    for (let i = 0; i < 3; i++) {
      const post = generatePost(page * 3 + i + 1);
      posts.push(post);
      feed.appendChild(renderPost(post));
    }
    page++;
    loading = false;
    if (page >= 10) {
      document.getElementById('feedLoader').textContent = 'Vous êtes à jour ! ✅';
    }
  }, 600);
}

/* Intersection Observer for infinite scroll */
const observer = new IntersectionObserver(entries => {
  if (entries[0].isIntersecting && page < 10) {
    loadPosts();
  }
}, { rootMargin: '200px' });
observer.observe(document.getElementById('feedLoader'));

/* ================================
   LIKE / SAVE / SHARE
================================ */
function toggleLike(id) {
  const post = posts.find(p => p.id === id);
  if (!post) return;
  post.liked = !post.liked;
  post.likes += post.liked ? 1 : -1;

  const btn = document.getElementById(`like-${id}`);
  btn.querySelector('.action-icon').textContent = post.liked ? '❤️' : '🤍';
  btn.classList.toggle('liked', post.liked);
  btn.setAttribute('aria-label', post.liked ? 'Ne plus aimer cette publication' : 'Aimer cette publication');
  btn.setAttribute('aria-pressed', post.liked);
  document.getElementById(`likes-count-${id}`).textContent = formatLikes(post.likes);

  if (post.liked) showToast('Publication aimée ❤️');
}

function handleDoubleLike(id) {
  const post = posts.find(p => p.id === id);
  if (!post || post.liked) return;
  const overlay = document.getElementById(`overlay-${id}`);
  overlay.classList.remove('pop');
  void overlay.offsetWidth; // reflow
  overlay.classList.add('pop');
  toggleLike(id);
}

function toggleSave(id) {
  const post = posts.find(p => p.id === id);
  if (!post) return;
  post.saved = !post.saved;
  const btn = document.getElementById(`save-${id}`);
  btn.querySelector('span').textContent = post.saved ? '🔖' : '📋';
  btn.setAttribute('aria-pressed', post.saved);
  btn.setAttribute('aria-label', post.saved ? 'Retirer des enregistrements' : 'Enregistrer');
  showToast(post.saved ? 'Publication enregistrée 🔖' : 'Publication retirée de vos enregistrements');
}

function sharePost(id) {
  if (navigator.share) {
    navigator.share({ title: 'Lumio', text: 'Regarde cette publication !', url: window.location.href });
  } else {
    navigator.clipboard?.writeText(window.location.href);
    showToast('Lien copié dans le presse-papier 📋');
  }
}

/* ================================
   COMMENTS
================================ */
function updateCommentBtn(id, val) {
  const btn = document.getElementById(`comment-btn-${id}`);
  if (val.trim()) {
    btn.classList.add('active');
    btn.disabled = false;
  } else {
    btn.classList.remove('active');
    btn.disabled = true;
  }
}

function submitComment(id) {
  const input = document.getElementById(`comment-${id}`);
  const text = input.value.trim();
  if (!text) return;
  const post = posts.find(p => p.id === id);
  if (!post) return;
  post.comments.push({ user: 'marie_lumio', text });
  input.value = '';
  updateCommentBtn(id, '');
  showToast('Commentaire publié 💬');
}

/* ================================
   FOLLOW
================================ */
function toggleFollow(btn, name) {
  const following = btn.classList.toggle('following');
  btn.textContent = following ? 'Abonné·e' : 'Suivre';
  btn.setAttribute('aria-label', following ? `Ne plus suivre ${name}` : `Suivre ${name}`);
  showToast(following ? `Vous suivez maintenant ${name} ✅` : `Vous ne suivez plus ${name}`);
}

/* ================================
   STORY MODAL
================================ */
function openStory(index) {
  storyIndex = index;
  renderStoryModal();
  document.getElementById('storyModal').classList.add('open');
  document.body.style.overflow = 'hidden';
  // Focus trap
  document.getElementById('storyModal').querySelector('.story-modal-close').focus();
}

function renderStoryModal() {
  const user = USERS[storyIndex];
  document.getElementById('storyModalAvatar').textContent = user.emoji;
  document.getElementById('storyModalName').textContent = user.name;
  document.getElementById('storyContent').textContent = EMOJIS[Math.floor(Math.random() * EMOJIS.length)];

  // Progress bars
  const prog = document.getElementById('storyProgress');
  prog.innerHTML = '';
  USERS.forEach((_, i) => {
    const bar = document.createElement('div');
    bar.className = 'story-bar' + (i < storyIndex ? ' done' : '');
    if (i === storyIndex) {
      bar.innerHTML = '<div class="story-bar-fill"></div>';
    }
    prog.appendChild(bar);
  });

  clearTimeout(storyTimer);
  storyTimer = setTimeout(() => {
    if (storyIndex < USERS.length - 1) {
      storyIndex++;
      renderStoryModal();
    } else {
      closeStory();
    }
  }, 4100);
}

function closeStory() {
  clearTimeout(storyTimer);
  document.getElementById('storyModal').classList.remove('open');
  document.body.style.overflow = '';
}

/* ================================
   UPLOAD MODAL
================================ */
function openUpload() {
  document.getElementById('uploadModal').classList.add('open');
  document.body.style.overflow = 'hidden';
  document.getElementById('uploadModal').querySelector('button').focus();
}
function closeUpload() {
  document.getElementById('uploadModal').classList.remove('open');
  document.body.style.overflow = '';
  document.getElementById('uploadPreview').style.display = 'none';
  document.getElementById('uploadZoneContent').style.display = 'block';
  document.getElementById('fileInput').value = '';
  document.getElementById('captionInput').value = '';
  document.getElementById('locationInput').value = '';
}

function handleDragOver(e) {
  e.preventDefault();
  document.getElementById('uploadZone').classList.add('drag-over');
}
function handleDragLeave() {
  document.getElementById('uploadZone').classList.remove('drag-over');
}
function handleDrop(e) {
  e.preventDefault();
  handleDragLeave();
  const file = e.dataTransfer.files[0];
  if (file && file.type.startsWith('image/')) loadPreview(file);
}

document.getElementById('fileInput').addEventListener('change', e => {
  const file = e.target.files[0];
  if (file) loadPreview(file);
});

function loadPreview(file) {
  const reader = new FileReader();
  reader.onload = ev => {
    const img = document.getElementById('uploadPreview');
    img.src = ev.target.result;
    img.style.display = 'block';
    img.alt = 'Aperçu de votre photo';
    document.getElementById('uploadZoneContent').style.display = 'none';
  };
  reader.readAsDataURL(file);
}

function submitPost() {
  const caption = document.getElementById('captionInput').value.trim();
  const location = document.getElementById('locationInput').value.trim();
  const previewSrc = document.getElementById('uploadPreview').src;

  const newPost = generatePost(posts.length + 1);
  newPost.user = { id: 0, name: 'marie_lumio', full: 'Marie Dupont', emoji: '🌟', color: '#7C3AED' };
  newPost.caption = caption || 'Nouveau moment partagé ✨';
  newPost.location = location;
  newPost.time = 'À l\'instant';
  newPost.emoji = '🌟';

  posts.unshift(newPost);
  const feed = document.getElementById('feedPosts');
  const el = renderPost(newPost);
  el.style.opacity = '0';
  el.style.transform = 'translateY(-20px)';
  el.style.transition = 'opacity 0.4s, transform 0.4s';
  feed.prepend(el);
  setTimeout(() => { el.style.opacity = '1'; el.style.transform = ''; }, 50);

  closeUpload();
  showToast('Publication partagée avec succès ! 🎉');
}

/* ================================
   TOAST
================================ */
function showToast(msg) {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.classList.add('show');
  clearTimeout(window._toastTimer);
  window._toastTimer = setTimeout(() => t.classList.remove('show'), 2800);
}

/* ================================
   PROFILE (placeholder)
================================ */
function openProfile() {
  showToast('Profil — fonctionnalité complète dans la version backend PHP/MySQL !');
}

/* ================================
   FORMAT LIKES
================================ */
function formatLikes(n) {
  if (n >= 1000) return (n / 1000).toFixed(1).replace('.0', '') + 'k';
  return n.toString();
}

/* ================================
   ACCESSIBILITY TOOLBAR
================================ */
// Theme
const btnTheme = document.getElementById('btnTheme');
btnTheme.addEventListener('click', () => {
  const dark = document.documentElement.getAttribute('data-theme') === 'dark';
  document.documentElement.setAttribute('data-theme', dark ? 'light' : 'dark');
  btnTheme.textContent = dark ? '🌙' : '☀️';
  btnTheme.setAttribute('aria-pressed', !dark);
  showToast(dark ? 'Thème clair activé ☀️' : 'Thème sombre activé 🌙');
  localStorage.setItem('lumio-theme', dark ? 'light' : 'dark');
});

// DYS
const btnDys = document.getElementById('btnDys');
btnDys.addEventListener('click', () => {
  const on = document.documentElement.getAttribute('data-dys') === 'true';
  document.documentElement.setAttribute('data-dys', !on);
  btnDys.setAttribute('aria-pressed', !on);
  showToast(!on ? 'Mode DYS activé 𝔸' : 'Mode DYS désactivé');
  localStorage.setItem('lumio-dys', !on);
});

// Daltonien
const btnDal = document.getElementById('btnDaltonien');
btnDal.addEventListener('click', () => {
  const on = document.documentElement.getAttribute('data-daltonien') === 'true';
  document.documentElement.setAttribute('data-daltonien', !on);
  btnDal.setAttribute('aria-pressed', !on);
  showToast(!on ? 'Mode daltonien activé 👁' : 'Mode daltonien désactivé');
  localStorage.setItem('lumio-daltonien', !on);
});

// Zoom
document.getElementById('btnZoomIn').addEventListener('click', () => {
  fontSize = Math.min(fontSize + 2, 24);
  document.documentElement.style.setProperty('--base-font-size', fontSize + 'px');
  document.documentElement.style.fontSize = fontSize + 'px';
  showToast('Texte agrandi : ' + fontSize + 'px');
  localStorage.setItem('lumio-fontsize', fontSize);
});
document.getElementById('btnZoomOut').addEventListener('click', () => {
  fontSize = Math.max(fontSize - 2, 12);
  document.documentElement.style.fontSize = fontSize + 'px';
  showToast('Texte réduit : ' + fontSize + 'px');
  localStorage.setItem('lumio-fontsize', fontSize);
});
document.getElementById('btnZoomReset').addEventListener('click', () => {
  fontSize = 16;
  document.documentElement.style.fontSize = '16px';
  showToast('Taille par défaut restaurée');
  localStorage.setItem('lumio-fontsize', 16);
});

// Toggle sidebar
document.getElementById('a11yToggle').addEventListener('click', () => {
  document.getElementById('a11yBar').classList.toggle('collapsed');
});

/* ================================
   UPLOAD BUTTONS
================================ */
document.getElementById('btnUpload').addEventListener('click', openUpload);
document.getElementById('btnUploadMobile')?.addEventListener('click', openUpload);

/* ================================
   KEYBOARD CLOSE MODALS
================================ */
document.addEventListener('keydown', e => {
  if (e.key === 'Escape') {
    if (document.getElementById('storyModal').classList.contains('open')) closeStory();
    if (document.getElementById('uploadModal').classList.contains('open')) closeUpload();
  }
});

/* Click outside to close */
document.getElementById('storyModal').addEventListener('click', e => {
  if (e.target === e.currentTarget) closeStory();
});
document.getElementById('uploadModal').addEventListener('click', e => {
  if (e.target === e.currentTarget) closeUpload();
});

/* ================================
   RESTORE PREFERENCES
================================ */
(function restorePrefs() {
  const theme = localStorage.getItem('lumio-theme');
  if (theme) {
    document.documentElement.setAttribute('data-theme', theme);
    btnTheme.textContent = theme === 'dark' ? '☀️' : '🌙';
    btnTheme.setAttribute('aria-pressed', theme === 'dark');
  }
  const dys = localStorage.getItem('lumio-dys');
  if (dys === 'true') {
    document.documentElement.setAttribute('data-dys', 'true');
    btnDys.setAttribute('aria-pressed', 'true');
  }
  const dal = localStorage.getItem('lumio-daltonien');
  if (dal === 'true') {
    document.documentElement.setAttribute('data-daltonien', 'true');
    btnDal.setAttribute('aria-pressed', 'true');
  }
  const fs = localStorage.getItem('lumio-fontsize');
  if (fs) {
    fontSize = parseInt(fs);
    document.documentElement.style.fontSize = fontSize + 'px';
  }
})();

/* System preference — dark mode */
if (!localStorage.getItem('lumio-theme') && window.matchMedia('(prefers-color-scheme: dark)').matches) {
  document.documentElement.setAttribute('data-theme', 'dark');
  btnTheme.textContent = '☀️';
}

/* ================================
   INIT
================================ */
renderStories();
renderSuggestions();
// Initial posts loaded by IntersectionObserver