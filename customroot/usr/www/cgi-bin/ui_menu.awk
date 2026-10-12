# One awk process per menu fragment, rather than shell processes per link.
function escape_html(value) {
	gsub(/&/, "\\&amp;", value)
	gsub(/</, "\\&lt;", value)
	gsub(/>/, "\\&gt;", value)
	gsub(/"/, "\\&quot;", value)
	return value
}

function bookmark_action(route) {
	if (index(route, "addbookmark()")) return "addbookmark"
	if (index(route, "rmbookmark()")) return "rmbookmark"
	if (index(route, "rmall()")) return "rmall"
	return ""
}

function render_item(label, route, action) {
	if (label == "<hr>") { print "<li class=\"menu-separator\" role=\"separator\"></li>"; return }
	action = bookmark_action(route)
	if (action != "") {
		printf "<li><button type=\"button\" onclick=\"return %s()\">%s</button></li>\n", action, escape_html(label)
		return
	}
	gsub(/^[ \t]+|[ \t]+$/, "", route)
	if (route !~ /(^\/cgi-bin\/|\.cgi|^https?:\/\/|^#$)/) return
	if (route !~ /^(\/|https?:\/\/|#)/) route = "/cgi-bin/" route
	printf "<li><a href=\"%s\">%s</a></li>\n", escape_html(route), escape_html(label)
}

NF >= 2 && $1 != "" { render_item($1, $2) }
