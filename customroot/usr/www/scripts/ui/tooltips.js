/* Legacy popUp/popDown hooks plus keyboard and touch access. */
var active_tooltip = null;

function popDown(id) {
    var tooltip = document.getElementById(id);
    if (!tooltip) return;
    tooltip.style.visibility = 'hidden';
    tooltip.setAttribute('aria-hidden', 'true');
    if (active_tooltip === id) active_tooltip = null;
}

function popUp(event, id) {
    var tooltip = document.getElementById(id);
    if (!tooltip) return;
    if (active_tooltip) popDown(active_tooltip);
    active_tooltip = id;
    tooltip.style.visibility = 'visible';
    tooltip.setAttribute('aria-hidden', 'false');
    var anchor = event.target.getBoundingClientRect();
    tooltip.style.left = Math.max(8, Math.min(anchor.left, innerWidth - tooltip.offsetWidth - 8)) + 'px';
    tooltip.style.top = Math.max(8, Math.min(anchor.bottom + 8, innerHeight - tooltip.offsetHeight - 8)) + 'px';
}

(function () {
    function tooltip_id(element) {
        var hook = element.getAttribute('onmouseover') || '';
        var match = hook.match(/popUp\(event,\s*['"]([^'"]+)['"]\)/);
        return match ? match[1] : null;
    }

    function show_for_control(event) {
        var id = tooltip_id(event.target);
        if (!id) return;
        event.target.setAttribute('aria-describedby', id);
        popUp(event, id);
    }

    document.addEventListener('focusin', show_for_control);
    document.addEventListener('touchstart', show_for_control, {passive: true});
    document.addEventListener('focusout', function () {
        if (active_tooltip) popDown(active_tooltip);
    });
    document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape' && active_tooltip) popDown(active_tooltip);
    });
}());
