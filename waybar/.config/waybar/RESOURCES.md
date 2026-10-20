# GTK Theming Resources

## Knowledge

- [GTK 4: CSS Overview](https://docs.gtk.org/gtk4/css-overview.html)
  Primary reference for GTK 4 CSS nodes, stylesheets, providers, and the default `gtk-4.0/gtk.css` loading path. Use for: understanding what GTK actually styles.
- [GTK 4: CSS Selectors](https://docs.gtk.org/gtk4/css-selectors.html)
  Exact selector grammar and specificity rules supported by GTK 4. Use for: checking whether a selector is valid and what it can match.
- [GTK 4: Interactive Debugging](https://docs.gtk.org/gtk4/running.html#interactive-debugging)
  Official entry point for GTK Inspector and runtime debugging. Use for: observing CSS nodes, classes, computed properties, and live changes.
- [GTK 4: Migrating from GTK 3 to GTK 4](https://docs.gtk.org/gtk4/migrating-3to4.html)
  Canonical inventory of removed style properties, changed CSS features, and structural differences. Use for: validating a suspected GTK 3/4 incompatibility.
- [GTK 3: CSS Overview](https://docs.gtk.org/gtk3/css-overview.html)
  Primary GTK 3 counterpart. Use for: comparing node concepts and the separate `gtk-3.0/gtk.css` loading path.
- [Waybar Wiki: Styling](https://github.com/Alexays/Waybar/wiki/Styling)
  Project-owned guide to Waybar’s application-specific selectors, stylesheet, logging, and Inspector workflow. Use for: translating GTK knowledge into Waybar changes.

## Wisdom (Communities)

- [GNOME Discourse](https://discourse.gnome.org/)
  GNOME’s moderated practitioner forum. Use for: GTK 4 behavior that remains unclear after checking widget and CSS documentation.
- [GTK Matrix room](https://matrix.to/#/#gtk:gnome.org)
  Real-time GTK community channel. Use for: small, evidence-rich questions that include GTK version, node tree, selector, and computed style.
- [Waybar issue tracker](https://github.com/Alexays/Waybar/issues)
  Maintainer and user reports for Waybar-specific widget-tree or stylesheet behavior. Search existing reports before filing a minimal reproduction.
