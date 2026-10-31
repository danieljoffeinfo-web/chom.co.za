(() => {
  const scene = document.querySelector('.preview-scene');
  const stage = document.querySelector('.preview-stage');
  const screen = document.querySelector('#feature-screen');
  const caption = document.querySelector('#preview-caption');
  const buttons = [...document.querySelectorAll('[data-feature]')];
  if (!scene || !stage || !screen) return;
  const overview = screen.innerHTML;
  const heading = (label, title, description) => `<div class="screen-kicker">${label}</div><h2>${title}</h2><p class="screen-subtitle">${description}</p>`;
  const features = {
    dashboard: {html: overview, caption: 'Your school day, together in one place.', nav: 0},
    timetable: {html: heading('YOUR TIMETABLE', 'A little structure.', '5–9 October · Grade 10B · Sample week') + '<div class="preview-week">' + [
      ['Monday', ['English', 'Mathematics', 'Afrikaans']],
      ['Tuesday', ['Mathematics', 'English', 'Life Sciences']],
      ['Wednesday', ['Geography', 'Mathematics', 'English']]
    ].map(([day, lessons]) => `<div class="preview-day"><b>${day}</b>${lessons.map((lesson, i) => `<div class="preview-lesson">${lesson}<small>${['09:40', '10:35', '11:30'][i]}</small></div>`).join('')}</div>`).join('') + '</div><a class="preview-screen-link" href="app/#timetable">See your full week ↗</a>', caption: 'Know what’s next, from your first class to your last.', nav: 3},
    assignments: {html: heading('YOUR ASSIGNMENTS', 'Room to do good work.', 'Two assignments. One place to keep track.') + '<div class="preview-assignment"><small>HISTORY · DUE FRIDAY</small><h3>Your WWI essay</h3><p>Keep your outline, notes and draft together.</p><div class="progress-label"><span>Draft progress</span><b>60%</b></div><div class="progress-track"><span></span></div></div><div class="preview-assignment"><small>LIFE SCIENCES · DUE FRIDAY</small><h3>Lab report</h3><p>Make your next small step.</p></div><a class="preview-screen-link" href="app/#assignments">Open assignments ↗</a>', caption: 'Keep drafts, notes and deadlines in one place.', nav: 4},
    chom: {html: heading('STUDY WITH CHOM', 'That lightbulb moment.', 'Guided practice, at your own pace.') + '<div class="study-example">x² + 5x + 6 = 0</div><p class="study-step"><b>Start with one small step.</b><br>Find two numbers that multiply to 6<br>and add to 5. You’ve got this.</p><a class="preview-screen-link" href="app/#chom">Try a guided session ↗</a><div class="mini-bottom">Guided exercises · Quick quizzes · Your notebook</div>', caption: 'Work through guided exercises, quick quizzes and study notes.', nav: 5}
  };
  buttons.forEach(button => button.addEventListener('click', () => {
    const feature = features[button.dataset.feature];
    if (!feature) return;
    buttons.forEach(item => item.setAttribute('aria-pressed', String(item === button)));
    screen.innerHTML = feature.html;
    caption.textContent = feature.caption;
    document.querySelectorAll('.mini-nav').forEach((item, i) => item.classList.toggle('selected', i === feature.nav));
  }));
  const fit = () => {
    const scale = Math.min(1, stage.clientWidth / 620);
    scene.style.setProperty('--scene-scale', scale);
    stage.style.height = `${550 * scale}px`;
  };
  fit();
  if ('ResizeObserver' in window) new ResizeObserver(fit).observe(stage);
  else window.addEventListener('resize', fit);
  const motion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const device = document.querySelector('.device');
  stage.addEventListener('pointermove', event => {
    if (motion.matches || event.pointerType !== 'mouse') return;
    const rect = stage.getBoundingClientRect();
    const x = (event.clientX - rect.left) / rect.width - .5;
    const y = (event.clientY - rect.top) / rect.height - .5;
    device.style.transform = `perspective(1200px) rotateY(${-8 + x * 5}deg) rotateX(${5 - y * 4}deg) rotateZ(-2deg)`;
  });
  stage.addEventListener('pointerleave', () => { device.style.transform = ''; });
  motion.addEventListener('change', () => { device.style.transform = ''; });
})();
