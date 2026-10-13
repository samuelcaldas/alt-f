# Shared HTML navigation; the .men files remain the source of routes.

# Escape text and attribute values without interpreting shell expressions.
ui_escape() {
	printf '%s' "$1" | sed 's/\&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g;s/"/\&quot;/g;s/'"'"'/\&#39;/g'
}

# Emit a same-window route or an explicitly saved external bookmark.
ui_menu_link() {
	local route
	route=$(printf '%s' "$2" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
	case "$route" in
		*.cgi*|/cgi-bin/*|http://*|https://*|'#') ;;
		*) return ;;
	esac
	case "$route" in /*|http://*|https://*|'#') ;; *) route="/cgi-bin/$route" ;; esac
	printf '<li><a href="%s">%s</a></li>\n' "$(ui_escape "$route")" "$(ui_escape "$1")"
}

# Render all installed submenu fragments for one menu category.
ui_menu_group() {
	local menu_file
	printf '<li><details><summary>%s</summary><ul>\n' "$(ui_escape "$1")"
	for menu_file in "$1"*.men; do
		test -f "$menu_file" || continue
		awk -F '|' -f ./ui_menu.awk "$menu_file"
	done
	echo '</ul></details></li>'
}

# Render accessible navigation without requiring JavaScript or a frameset.
ui_navigation() {
	local group
	echo '<nav id="site-navigation" aria-label="Main navigation"><ul class="ui-menu">'
	ui_menu_link Status /cgi-bin/status.cgi
	for group in Shortcuts $(cat Main.men); do ui_menu_group "$group"; done
	ui_menu_link Logout /cgi-bin/logout.cgi
	echo '</ul></nav>'
}
