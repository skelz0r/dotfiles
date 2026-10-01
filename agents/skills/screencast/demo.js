window.__demo = window.__demo || (() => {
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const pos = () => JSON.parse(sessionStorage.getItem('demoCursor') || '{"x":900,"y":500}');
  const cursor = () => {
    let c = document.getElementById('demo-cursor');
    if (!c) {
      c = document.createElement('div');
      c.id = 'demo-cursor';
      c.innerHTML = '<svg width="22" height="22" viewBox="0 0 24 24"><path d="M3 2l7 19 2.5-7.5L20 11z" fill="#161616" stroke="#fff" stroke-width="1.5"/></svg>';
      Object.assign(c.style, { position: 'fixed', zIndex: 99999, pointerEvents: 'none', left: '0', top: '0', transition: 'transform 0.15s' });
      document.body.appendChild(c);
      const p = pos();
      c.style.transform = `translate(${p.x}px, ${p.y}px)`;
    }
    return c;
  };
  const el = (s) => (typeof s === 'string' ? document.querySelector(s) : s);
  const scrollIntoView = async (target) => {
    const r = target.getBoundingClientRect();
    if (r.top < 90 || r.bottom > window.innerHeight - 60) {
      window.scrollBy({ top: r.top - window.innerHeight / 2, behavior: 'smooth' });
      await sleep(900);
    }
  };
  const move = async (s, ms = 700) => {
    const target = el(s);
    await scrollIntoView(target);
    const r = target.getBoundingClientRect();
    const to = { x: r.left + Math.min(r.width / 2, 40), y: r.top + r.height / 2 };
    const from = pos();
    const c = cursor();
    c.style.transition = 'none';
    const start = performance.now();
    await new Promise((done) => {
      const step = (now) => {
        const t = Math.min((now - start) / ms, 1);
        const e = t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
        const x = from.x + (to.x - from.x) * e;
        const y = from.y + (to.y - from.y) * e;
        c.style.transform = `translate(${x}px, ${y}px)`;
        if (t < 1) requestAnimationFrame(step); else done();
      };
      requestAnimationFrame(step);
    });
    sessionStorage.setItem('demoCursor', JSON.stringify(to));
  };
  const click = async (s, target) => {
    await move(s);
    const c = cursor();
    c.style.transition = 'transform 0.12s';
    const p = pos();
    c.style.transform = `translate(${p.x}px, ${p.y}px) scale(0.8)`;
    await sleep(150);
    c.style.transform = `translate(${p.x}px, ${p.y}px)`;
    await sleep(120);
    el(target || s).click();
  };
  const type = async (s, text, delay = 55) => {
    await click(s);
    const input = el(s);
    input.focus();
    for (const ch of text) {
      input.value += ch;
      input.dispatchEvent(new Event('input', { bubbles: true }));
      await sleep(delay + Math.random() * 40);
    }
  };
  const scroll = async (dy, ms = 1200) => {
    window.scrollBy({ top: dy, behavior: 'smooth' });
    await sleep(ms);
  };
  const button = (text) => [...document.querySelectorAll('button, a.fr-btn')].find((b) => b.textContent.trim().includes(text));
  return { sleep, cursor, move, click, type, scroll, button };
})();
window.__demo.cursor();
