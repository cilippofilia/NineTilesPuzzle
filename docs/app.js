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
