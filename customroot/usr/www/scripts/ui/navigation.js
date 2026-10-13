/* Progressive enhancements only: links and native form submission stay intact. */
(function () {
    'use strict';

    function initialize_navigation() {
        var navigation = document.getElementById('site-navigation');
        var toggle = document.querySelector('.navigation-toggle');
        if (!navigation || !toggle) return;
        document.body.classList.add('ui-enhanced');
        toggle.addEventListener('click', function () {
            var opened = navigation.classList.toggle('is-open');
            toggle.setAttribute('aria-expanded', String(opened));
        });
    }

    function describe_input(input) {
        if (input.type === 'hidden' || input.type === 'submit' || input.type === 'button') return;
        if (input.labels && input.labels.length) return;
        if (input.hasAttribute('aria-label') || input.hasAttribute('aria-labelledby')) return;
        var row = input.closest('tr');
        var caption = row && row.cells.length ? row.cells[0].textContent.trim() : '';
        input.setAttribute('aria-label', caption || input.name.replace(/_/g, ' ') || 'Value');
    }

    function prepare_table(table) {
        if (table.dataset.uiPrepared) return;
        table.dataset.uiPrepared = 'yes';
        var row = table.rows[0];
        var is_data = table.querySelector('th') || (row && row.cells.length > 3);
        table.classList.add(is_data ? 'data-table' : 'form-table');
        if (!is_data || table.parentElement.classList.contains('table-scroll')) return;
        var wrapper = document.createElement('div');
        wrapper.className = 'table-scroll';
        wrapper.tabIndex = 0;
        wrapper.setAttribute('role', 'region');
        wrapper.setAttribute('aria-label', 'Scrollable table');
        table.parentNode.insertBefore(wrapper, table);
        wrapper.appendChild(table);
    }

    function enhance_content(root) {
        root.querySelectorAll('table').forEach(prepare_table);
        root.querySelectorAll('input, select, textarea').forEach(describe_input);
    }

    function observe_content() {
        var content = document.getElementById('main-content') || document.body;
        enhance_content(content);
        new MutationObserver(function (changes) {
            changes.forEach(function (change) {
                change.addedNodes.forEach(function (node) {
                    if (node.nodeType !== 1) return;
                    if (node.matches('table')) prepare_table(node);
                    enhance_content(node);
                });
            });
        }).observe(content, {childList: true, subtree: true});
    }

    document.addEventListener('DOMContentLoaded', function () {
        initialize_navigation();
        observe_content();
    });
}());
