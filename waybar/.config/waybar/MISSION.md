# Mission: Diagnose GTK 3 vs GTK 4 theming

## Why
Figure out why a theming process that works in GTK 3 fails in GTK 4, so GTK and Waybar styling problems can be diagnosed from evidence instead of trial-and-error CSS edits.

## Success looks like
- Identify whether a failure is caused by stylesheet loading, selector matching, or declaration support
- Use GTK Inspector to find the real CSS node name, ID, classes, and state
- Choose the correct GTK-version configuration path and verify which GTK library an application uses
- Explain why GTK 3 CSS, GTK 4 CSS, Waybar CSS, and libadwaita styling are related but not interchangeable

## Constraints
- Assume no prior GTK development experience
- Anchor examples in the installed Waybar theme and local GTK tools
- Prefer short visual lessons with immediate diagnostic practice
- Do not require writing a GTK application in C

## Out of scope
- Porting a GTK 3 application to GTK 4
- Authoring a complete desktop theme
- GTK widget subclassing and custom rendering
