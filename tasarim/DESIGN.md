---
name: Matchfit Design Core
colors:
  surface: '#121414'
  surface-dim: '#121414'
  surface-bright: '#37393a'
  surface-container-lowest: '#0c0f0f'
  surface-container-low: '#1a1c1c'
  surface-container: '#1e2020'
  surface-container-high: '#282a2b'
  surface-container-highest: '#333535'
  on-surface: '#e2e2e2'
  on-surface-variant: '#c3c5d9'
  inverse-surface: '#e2e2e2'
  inverse-on-surface: '#2f3131'
  outline: '#8d90a2'
  outline-variant: '#434656'
  surface-tint: '#b7c4ff'
  primary: '#b7c4ff'
  on-primary: '#002682'
  primary-container: '#0052ff'
  on-primary-container: '#dfe3ff'
  inverse-primary: '#004ced'
  secondary: '#ffffff'
  on-secondary: '#283500'
  secondary-container: '#c3f400'
  on-secondary-container: '#556d00'
  tertiary: '#c8c6c5'
  on-tertiary: '#313030'
  tertiary-container: '#676666'
  on-tertiary-container: '#e7e4e4'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#dde1ff'
  primary-fixed-dim: '#b7c4ff'
  on-primary-fixed: '#001452'
  on-primary-fixed-variant: '#0038b6'
  secondary-fixed: '#c3f400'
  secondary-fixed-dim: '#abd600'
  on-secondary-fixed: '#161e00'
  on-secondary-fixed-variant: '#3c4d00'
  tertiary-fixed: '#e5e2e1'
  tertiary-fixed-dim: '#c8c6c5'
  on-tertiary-fixed: '#1c1b1b'
  on-tertiary-fixed-variant: '#474646'
  background: '#121414'
  on-background: '#e2e2e2'
  surface-variant: '#333535'
typography:
  display:
    fontFamily: Inter
    fontSize: 40px
    fontWeight: '800'
    lineHeight: 48px
    letterSpacing: -0.02em
  h1:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.01em
  h2:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  h3:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '500'
    lineHeight: 26px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
  label-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  caption:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 8px
  container-padding: 24px
  stack-sm: 8px
  stack-md: 16px
  stack-lg: 24px
  inline-gutter: 12px
---

## Brand & Style

The design system is built to bridge the gap between high-performance athletic achievement and the fluid nature of social connectivity. It prioritizes **Speed** and **Energy** through a high-contrast visual language, while maintaining **Trust** through a structured, minimalist layout. 

The aesthetic style is a hybrid of **High-Contrast Modern** and **Glassmorphism**. This combination allows for aggressive, sporty call-to-actions that demand attention, paired with sophisticated, translucent layers that provide depth and context without cluttering the mobile interface. The interface should feel like a premium fitness wearable—functional, sleek, and instantly responsive.

## Colors

The palette revolves around the tension between **Electric Blue** (Trust & Depth) and **Neon Green** (Action & Vitality). 

- **Electric Blue (#0052FF):** Used for primary brand moments, progress indicators, and primary interactive elements.
- **Neon Green (#CCFF00):** Reserved exclusively for high-priority CTAs, "Join" actions, and active states. It should be used sparingly to maintain its impact.
- **Neutral Grayscale:** In Dark Mode, the background uses a Deep Charcoal (#121212) to reduce eye strain and make the neon accents pop. In Light Mode, Clean White provides a high-energy, clinical look.
- **Glassmorphism:** Use 20% opacity of the surface color combined with a 20px background blur for navigation bars and floating overlays.

## Typography

This design system utilizes **Inter** across all levels to maintain a systematic and utilitarian feel. 

Headlines use **Bold (700)** and **Extra Bold (800)** weights with tight letter-spacing to evoke a sense of urgency and strength. Body copy is set at **Medium (500)** weight rather than Regular to ensure legibility against dark, high-contrast backgrounds and to maintain the "sporty" visual density. Labels and small metadata should often utilize uppercase styling with increased tracking to differentiate them from interactive body text.

## Layout & Spacing

The layout philosophy follows a **fluid grid** model optimized for mobile-first consumption. 

- **Rhythm:** An 8px linear scale governs all padding and margin decisions. 
- **Safe Zones:** Content is inset by 24px from the screen edges to provide breathing room and prevent accidental touches near bezel edges.
- **Grid:** Use a 4-column layout for mobile vertical views. Card components should span the full width of the container or be arranged in a 2-column horizontal scroll for "Match" or "Player" discovery.
- **Vertical Spacing:** Use 32px or 40px blocks to separate distinct sections (e.g., "Trending Groups" from "Your Schedule") to emphasize the minimalist philosophy.

## Elevation & Depth

Visual hierarchy is established through **Backdrop Blurs** and **Ambient Shadows**.

1.  **Level 0 (Background):** Deep Charcoal or White base.
2.  **Level 1 (Cards):** Surface color with a 1px low-opacity border (Light: 10% Black, Dark: 10% White).
3.  **Level 2 (Active Elements/Modals):** Subtle 15% opacity shadows tinted with the primary color (#0052FF) to create a "glow" effect rather than a traditional drop shadow.
4.  **Navigation:** Navigation bars and tab bars use Glassmorphism—70% transparency with a heavy (32px) blur effect. This ensures that content is visible as it scrolls beneath, reinforcing the feeling of "Speed" and continuity.

## Shapes

The shape language is defined by a **24px (1.5rem) corner radius**, applied consistently to all primary cards, buttons, and input fields. This high degree of roundedness communicates friendliness and social connection, softening the "aggressive" nature of the neon palette.

- **Standard Elements:** 24px radius.
- **Chips/Badges:** Full pill-shape (circular ends).
- **Icons:** Set within 48x48px circular or rounded-square containers to ensure touch-target compliance.

## Components

### Buttons
- **Primary:** Neon Green background with Black text (#121212). Bold 16px font. 24px radius.
- **Secondary:** Electric Blue background with White text.
- **Ghost:** Transparent background with a 2px Electric Blue border.

### Input Fields
- Filled style with a 24px radius. Background should be 5% lighter than the main background in dark mode. 
- Active state is indicated by a 2px Neon Green border.

### Cards (The "Match" Card)
- High-contrast containers with 24px corners. 
- Include a "Glass" overlay footer for metadata like "Time" or "Location."
- Elevation should be flat, using a 1px border for separation unless the card is a "Featured" element, which uses a blue ambient shadow.

### Navigation Bars
- Bottom tab bar must be glassmorphic. 
- Active icons use the Neon Green color, while inactive states use a 50% opacity Neutral White/Gray.

### Chips & Tags
- Used for sports categories (e.g., "Basketball," "5v5"). 
- Pill-shaped with a subtle 10% Electric Blue fill and 100% Blue text.

### High-Contrast Iconography
- Use a 2px stroke weight. 
- Icons should be strictly geometric and non-decorative. In active states, icons can take a "Dual-tone" appearance using both Primary and Secondary colors.