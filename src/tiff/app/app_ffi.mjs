export function scrollToBottom(root, selector) {
  const anchor = root.querySelector(selector);

  if (anchor) {
    anchor.scrollIntoView({ behavior: "smooth" });
  } else {
    console.warn("could not find ${selector}");
  }
}
