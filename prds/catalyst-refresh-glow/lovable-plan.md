

## Plan: Compact Layout with Proper Alignment

The page currently has excessive vertical spacing at every level: section padding, heading-to-content gaps, internal element spacing, and the hero takes up the full viewport height. This plan tightens everything while keeping it breathable.

### Changes (single file: `src/pages/landing/FinancialAdvisorsLP.tsx`)

**1. Section Padding** — All sections from `py-20 md:py-28` down to `py-14 md:py-20`. This alone saves ~200px+ across the page.

**2. Hero** — Remove `min-h-[calc(100vh-72px)]` so it sizes to content. Reduce internal padding from `py-16` to `py-12`. Tighten the pill badge margin from `mb-10` to `mb-6`. Reduce trust bar `mt-10 pt-6` to `mt-8 pt-5`. Reduce grid gap from `gap-12 lg:gap-20` to `gap-10 lg:gap-16`.

**3. Video** — Reduce video container margin from `mt-16` to `mt-10`.

**4. Value** — Reduce heading-to-cards gap from `mb-14` to `mb-10`. Tighten the right paragraph spacing. Card min-height from `300px` to `260px`.

**5. Secret** — Reduce grid gap from `gap-16 lg:gap-24` to `gap-10 lg:gap-16`. Tighten secret items `mt-10` to `mt-8`. CTA button `mt-10` to `mt-8`.

**6. Metrics Bar** — Reduce padding from `py-20 md:py-24` to `py-12 md:py-16`. Inner card padding from `p-8 md:p-12` to `p-6 md:p-8`. Number sizes from `text-5xl md:text-6xl lg:text-7xl` to `text-4xl md:text-5xl lg:text-6xl`.

**7. Services** — Heading margin from `mb-14` to `mb-10`.

**8. Pricing** — Heading margin from `mb-14` (via the paragraph `mb-14`) to `mb-10`. Card padding from `p-8 md:p-10` to `p-7 md:p-8`.

**9. Testimonials** — Heading margin from `mb-14` to `mb-10`. Card padding from `p-8 md:p-9` to `p-6 md:p-7`.

**10. Process** — Heading margin from `mb-14` to `mb-10`. Icon container from `104px` to `88px`, inner icon from `80px` to `64px`. Gap between steps from `gap-10 md:gap-6` to `gap-8 md:gap-6`. CTA margin from `mt-16` to `mt-10`.

**11. About** — Heading margin from `mb-12` to `mb-8`. Image min-height from `420px` to `360px`. Bottom cards margin from `mt-5` to `mt-4`.

**12. Contact** — Grid gap from `gap-16 lg:gap-20` to `gap-10 lg:gap-14`. Benefits list `mt-10` to `mt-6`, space between items from `space-y-5` to `space-y-3`.

**13. Footer** — Inner padding from `py-16` to `py-12`. Grid gap from `gap-12` to `gap-8`.

