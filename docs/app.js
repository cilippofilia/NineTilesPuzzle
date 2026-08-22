const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

// Reveal sections as they scroll into view.
const sections = document.querySelectorAll("main section");
if (reduceMotion || !("IntersectionObserver" in window)) {
  sections.forEach((el) => el.classList.add("in-view"));
} else {
  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          entry.target.classList.add("in-view");
          observer.unobserve(entry.target);
        }
      }
    },
    { threshold: 0.15 }
  );
  sections.forEach((el) => observer.observe(el));
}

// Countdown to release.
const countdown = document.getElementById("countdown");
if (countdown) {
  const releaseDate = new Date(countdown.dataset.release).getTime();
  const daysEl = document.getElementById("cd-days");
  const hoursEl = document.getElementById("cd-hours");
  const minutesEl = document.getElementById("cd-minutes");
  const secondsEl = document.getElementById("cd-seconds");
  const releaseLive = document.getElementById("release-live");
  const badgePre = document.getElementById("badge-pre");
  const badgePost = document.getElementById("badge-post");
  const betaNote = document.getElementById("beta-note");

  const pad = (n) => String(n).padStart(2, "0");

  const setValue = (el, value) => {
    const digits = el.querySelectorAll(".digit");
    for (let i = 0; i < digits.length; i++) {
      const digit = digits[i];
      const char = value[i];
      if (digit.textContent === char) continue;
      digit.textContent = char;
      digit.classList.remove("tick");
      void digit.offsetWidth; // restart animation
      digit.classList.add("tick");
    }
  };

  const goLive = () => {
    countdown.hidden = true;
    releaseLive.hidden = false;
    badgePre.hidden = true;
    betaNote.hidden = true;
    badgePost.hidden = false;
    clearInterval(timer);
  };

  const tick = () => {
    const diff = releaseDate - Date.now();
    if (diff <= 0) {
      goLive();
      return;
    }
    const totalSeconds = Math.floor(diff / 1000);
    setValue(daysEl, pad(Math.floor(totalSeconds / 86400)));
    setValue(hoursEl, pad(Math.floor((totalSeconds % 86400) / 3600)));
    setValue(minutesEl, pad(Math.floor((totalSeconds % 3600) / 60)));
    setValue(secondsEl, pad(totalSeconds % 60));
  };

  tick();
  const timer = setInterval(tick, 1000);
}
