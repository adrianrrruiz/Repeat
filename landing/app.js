const examples = {
  water: {
    value: 2,
    initial: 2,
    goal: 8,
    step: 1,
    unit: "vasos",
    name: "Beber agua",
  },
  reading: {
    value: 10,
    initial: 10,
    goal: 20,
    step: 5,
    unit: "min",
    name: "Leer un poco",
  },
  mindful: {
    value: 0,
    initial: 0,
    goal: 5,
    step: 1,
    unit: "min",
    name: "Una pausa",
  },
};
const status = document.querySelector("#demo-status");
function renderHabits() {
  for (const [id, habit] of Object.entries(examples)) {
    const row = document.querySelector(`[data-habit="${id}"]`);
    const button = row.querySelector("[data-add]");
    const done = habit.value >= habit.goal;
    row.style.setProperty(
      "--progress",
      `${Math.min(100, (habit.value / habit.goal) * 100)}%`,
    );
    row.querySelector(".habit-value").textContent =
      `${habit.value} de ${habit.goal} ${habit.unit}`;
    button.disabled = done;
    button
      .querySelector("use")
      .setAttribute("href", done ? "#i-check" : "#i-plus");
    const action =
      id === "water"
        ? "Añadir un vaso de agua"
        : id === "reading"
          ? "Añadir cinco minutos de lectura"
          : "Añadir un minuto de pausa";
    button.setAttribute(
      "aria-label",
      done ? `${habit.name}, completado` : action,
    );
  }
  const habits = Object.values(examples);
  const completed =
    1 + habits.filter((habit) => habit.value >= habit.goal).length;
  const percentage = Math.round(
    ((1 +
      habits.reduce(
        (total, habit) => total + Math.min(1, habit.value / habit.goal),
        0,
      )) /
      4) *
      100,
  );
  document.querySelector("#daily-summary").textContent =
    `${completed} de 4 hábitos completados`;
  document.querySelector("#daily-percentage").textContent = `${percentage} %`;
  document.querySelector("#daily-fill").style.width = `${percentage}%`;
}
document.querySelectorAll("[data-add]").forEach((button) =>
  button.addEventListener("click", () => {
    const habit = examples[button.dataset.add];
    habit.value = Math.min(habit.goal, habit.value + habit.step);
    renderHabits();
    status.textContent = `${habit.name}: ${habit.value} de ${habit.goal} ${habit.unit}.${habit.value === habit.goal ? " Hábito completado." : ""}`;
  }),
);
document.querySelector("#reset-demo").addEventListener("click", () => {
  Object.values(examples).forEach((habit) => {
    habit.value = habit.initial;
  });
  renderHabits();
  status.textContent = "La demostración se ha reiniciado.";
});
const descriptions = {
  quantity: [
    "Cada pequeño gesto suma.",
    "Elige una meta, añade lo que hiciste y mira cómo tu hábito se llena. Así de sencillo.",
  ],
  time: [
    "Un momento para lo que importa.",
    "Una sesión de lectura o una pausa para respirar. Usa el temporizador o registra el tiempo a tu manera.",
  ],
  history: [
    "Tu constancia tiene una historia.",
    "Vuelve a cualquier día, mira tus registros y reconoce todo lo que has construido, paso a paso.",
  ],
};
const tabs = [...document.querySelectorAll("[data-tab]")];
function selectTab(tab, focus = false) {
  tabs.forEach((item) => {
    const selected = item === tab;
    item.setAttribute("aria-selected", String(selected));
    item.tabIndex = selected ? 0 : -1;
    document.querySelector(`#panel-${item.dataset.tab}`).hidden = !selected;
  });
  const [heading, description] = descriptions[tab.dataset.tab];
  document.querySelector("#tab-heading").textContent = heading;
  document.querySelector("#tab-description").textContent = description;
  if (focus) tab.focus();
}
tabs.forEach((tab, index) => {
  tab.addEventListener("click", () => selectTab(tab));
  tab.addEventListener("keydown", (event) => {
    let next;
    if (event.key === "ArrowRight") next = tabs[(index + 1) % tabs.length];
    if (event.key === "ArrowLeft")
      next = tabs[(index - 1 + tabs.length) % tabs.length];
    if (event.key === "Home") next = tabs[0];
    if (event.key === "End") next = tabs[tabs.length - 1];
    if (next) {
      event.preventDefault();
      selectTab(next, true);
    }
  });
});
const grid = document.querySelector(".history-grid");
// A fixed illustrative pattern, never a real person's history.
for (let index = 0; index < 60; index++) {
  const cell = document.createElement("i");
  cell.dataset.level = String((index * 7 + Math.floor(index / 9)) % 4);
  grid.append(cell);
}
let dialogOpener = null;
function openDialog(name, opener) {
  const dialog = document.querySelector(`#${name}-dialog`);
  dialogOpener = opener;
  dialog.showModal();
  document.body.classList.add("dialog-open");
}
document
  .querySelectorAll("[data-dialog]")
  .forEach((button) =>
    button.addEventListener("click", () =>
      openDialog(button.dataset.dialog, button),
    ),
  );
document.querySelectorAll("dialog").forEach((dialog) => {
  dialog
    .querySelector(".close-dialog")
    .addEventListener("click", () => dialog.close());
  dialog.addEventListener("click", (event) => {
    const box = dialog.getBoundingClientRect();
    if (
      event.target === dialog &&
      (event.clientX < box.left ||
        event.clientX > box.right ||
        event.clientY < box.top ||
        event.clientY > box.bottom)
    )
      dialog.close();
  });
  dialog.addEventListener("close", () => {
    document.body.classList.remove("dialog-open");
    dialogOpener?.focus();
  });
});
document.querySelector("#launch-demo").addEventListener("click", () => {
  const dialog = document.querySelector("#launch-dialog");
  dialog.close();
  document.querySelector("#experiencia").scrollIntoView({
    behavior: matchMedia("(prefers-reduced-motion: reduce)").matches
      ? "instant"
      : "smooth",
    block: "center",
  });
  (
    document.querySelector('[data-add="water"]:not(:disabled)') ??
    document.querySelector("#reset-demo")
  ).focus({ preventScroll: true });
});
renderHabits();
