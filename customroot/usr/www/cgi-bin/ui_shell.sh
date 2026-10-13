# Presentation helpers: no service operations or additional authentication.

# Emit the document head once; theme assets remain local to the NAS.
ui_document_head() {
	printf 'Content-Type: text/html; charset=UTF-8\r\n\r\n'
	cat <<-EOF
		<!DOCTYPE html>
		<html lang="en"><head><meta charset="utf-8">
		<meta name="viewport" content="width=device-width, initial-scale=1">
		<title>$(ui_escape "$1")</title><link rel="icon" href="/dns-323.png">
		<link rel="stylesheet" href="/scripts/ui/layout.css">
		$(load_thm default.thm)
		<style>$LOCAL_STYLE</style>
		<script defer src="/scripts/ui/navigation.js"></script>
		<script defer src="/scripts/ui/tooltips.js"></script>
		<script defer src="/scripts/ui/bookmarks.js"></script>
		</head>
	EOF
}

# Preserve top-only, side-only and both enabled menu preferences.
ui_menu_layout() {
	case "$SIDE_MENU:$TOP_MENU" in
		no:*) echo top ;;
		*:no) echo sidebar ;;
		*) echo 'sidebar ui-both' ;;
	esac
}

# Open the body with the existing authored onload action.
ui_body_open() {
	local action
	action=""; test -n "$1" && action="onload=\"$1\""
	echo "<body class=\"ui-page ui-$2\" $action>"
	echo '<a class="skip-link" href="#main-content">Skip to content</a>'
	echo '<header class="ui-brand"><a href="/cgi-bin/status.cgi">Alt-F</a><button class="navigation-toggle" type="button" aria-controls="site-navigation" aria-expanded="false">Menu</button></header>'
}

# Reuse already-rendered HTML for the optional desktop top menu.
ui_top_navigation() {
	case "$2" in *ui-both*) ;; *) return ;; esac
	printf '%s\n' "$1" | sed 's/id="site-navigation" aria-label="Main navigation"/id="top-navigation" class="desktop-navigation" aria-label="Top navigation"/'
}

# Open a normal administrative page without regenerating the menu twice.
ui_document_body() {
	local layout navigation
	layout=$(ui_menu_layout); navigation=""
	case "$(basename "$0")" in login.cgi) layout=top ;; *) navigation=$(ui_navigation) ;; esac
	ui_body_open "$1" "$layout"
	ui_top_navigation "$navigation" "$layout"
	echo '<div class="ui-layout">'
	printf '%s\n' "$navigation"
	echo '<main id="main-content" tabindex="-1">'
	UI_PAGE_FULL=yes
}

# Emit the title and existing contextual help link.
ui_page_title() {
	local help_file
	help_file="$(basename "$0" .cgi)_hlp.html"
	printf '<h1 class="title">%s' "$(ui_escape "$1")"
	test ! -f "/usr/www/$help_file" || printf ' <a class="page-help" href="/%s" target="_blank" rel="noopener">Help</a>' "$help_file"
	echo '</h1>'
}

# Preserve the existing unsaved-settings notice and first-boot instructions.
ui_settings_notice() {
	if loadsave_settings -st >/dev/null; then return; fi
	warn_tt="The following files have changed since the last save:<br>$(loadsave_settings -lc | sed -n 's/ /<br>/gp')"
	mktt tt_settings "$warn_tt"
	echo "<p class=\"warn settings-notice\"><a href=\"/cgi-bin/settings.cgi\" $(ttip tt_settings)>When done you must save settings</a></p>"
}

# Close full or minimal HTML without wrapping redirects or downloads.
write_footer() {
	test "$UI_PAGE_FULL" != yes || echo '</main></div>'
	echo '</body></html>'
}

# Redirect expired sessions to the login route, preserving the encoded local URI.
ui_login_redirect() {
	local destination
	destination=$REQUEST_URI
	case "$destination" in /cgi-bin/*) ;; *) destination=/cgi-bin/status.cgi ;; esac
	printf 'Status: 303 See Other\r\nLocation: /cgi-bin/login.cgi?%s\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n' "$(url_encode "$destination")"
	exit 0
}
