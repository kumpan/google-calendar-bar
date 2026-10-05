# dmgbuild settings for the installer window (see build.sh). Writes the Finder layout directly into the
# image's .DS_Store, so it works on CI without scripting Finder.
#   dmgbuild -s scripts/dmg-settings.py -D app=dist/CalendarBar.app -D background=<png> CalendarBar out.dmg
# background@2x.png next to the background is picked up for Retina screens.

app = defines["app"]  # noqa: F821 (provided by dmgbuild)
files = [app]
symlinks = {"Applications": "/Applications"}

# Matches scripts/make-dmg-background.swift: icons either side of the arrow.
background = defines["background"]  # noqa: F821
window_rect = ((200, 140), (660, 432))  # 400 pt of content plus the 32 pt title bar
icon_locations = {"CalendarBar.app": (180, 215), "Applications": (480, 215)}
icon_size = 128
text_size = 14

default_view = "icon-view"
show_toolbar = False
show_status_bar = False
show_tab_view = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False

format = "UDZO"
filesystem = "HFS+"
