# Repeat landing · design direction

Skills applied: frontend-design (Anthropic) and better-ui (Jakub Krehel), selected through ui-skills.com.

## Tokens and direction

- Base: mist #f5f8f3, white #ffffff; evergreen ink #293e34.
- Accents drawn from the habit cards: pink #f99bb5, lilac #d8d9f5, blue #bfdef4, mint #bfe3cf.
- Bricolage Grotesque carries friendly, compact display type; Manrope keeps the smaller copy clear. Fonts are served locally with their licenses.
- Main composition: oversized left-aligned statement beside one interactive phone. A quieter editorial section gives way to a selectable metric demonstration, three concrete habit capabilities, privacy, real FAQs and a closing invitation.

```text
[repeat]            [experience / rhythm / privacy] [iPhone]
[large headline + action]       [interactive habit phone]
[three essential principles]
[short manifesto]               [human explanation]
[metric selector + explanation] [one changing metric panel]
[three distinct habit examples]
[private-by-default narrative]  [iPhone → optional iCloud]
[questions]                    [native disclosure rows]
[closing invitation]
```

## Critique before implementation

A cream/serif/clay palette was rejected as unrelated to Repeat. An evergreen and pale mint base uses the app's existing soft habit colors instead. One phone, rather than a gallery of floating feature cards, makes the actual product behavior the central visual. No fake testimonials, download badges, invented users or active-iCloud promises. The page's only retained state is in memory.

## Interaction and craft

- Habit increments reveal actual proportional fills, completion labels and overall percentage.
- Tabs switch examples without decorative entrance loops; arrow keys navigate the tablist.
- Native dialogs, keyboard focus, visible states and reduced-motion support.
- Interactive scale is exactly 0.96 over 150ms only without reduced motion. Hover styles apply only to hover-capable pointers.
- No analytics, forms, third-party browser fonts or habit API. Hosting request processing is disclosed in the privacy dialog.
