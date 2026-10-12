/* Keep the CGI bookmark contract, using the current document rather than frames. */
function commonbookmark() {
    var form = document.forms.namedItem('embedf');
    var title = form ? form.elements.namedItem('ifname').value : document.title;
    var url = form ? form.elements.namedItem('ifsrc').value : location.pathname + location.search;
    return encodeURIComponent(title) + '&url=' + encodeURIComponent(url);
}

function addbookmark() {
    location.assign('/cgi-bin/bookmark.cgi?add=' + commonbookmark());
    return false;
}

function rmbookmark() {
    location.assign('/cgi-bin/bookmark.cgi?rm=' + commonbookmark());
    return false;
}

function rmall() {
    var form = document.forms.namedItem('embedf');
    var url = form ? form.elements.namedItem('ifsrc').value : location.pathname + location.search;
    location.assign('/cgi-bin/bookmark.cgi?rm=all&url=' + encodeURIComponent(url));
    return false;
}
