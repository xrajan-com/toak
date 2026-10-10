# App icon history

Every image that has ever been the X Poker app icon, kept so nothing is lost
when the icon changes. Files are named `app-icon-<first-used date>-<label>.png`;
`index.json` lists them oldest first with a note on where each one came from.
The newest entry is the current icon, the same image as
`../app-icon-master.png`.

To change the icon, never overwrite files here. Run:

    python3 tools/generate_app_icons.py --replace path/to/new-icon.png --label short-name

That keeps the outgoing icon here, records the new one, makes it the master
and regenerates every Play, Android and iOS size. The first five entries were
recovered from git history at their largest surviving size.
