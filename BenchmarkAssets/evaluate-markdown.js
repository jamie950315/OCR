/* Trusted, DOM-free Markdown extraction. Model output is data, never JavaScript. */
function extractBenchmarkMarkdown(source) {
    var md = markdownit('commonmark', {html: true}).enable('table');
    var tokens = md.parse(source, {});
    var count = 0, errors = [];
    tokens.forEach(function(token) {
        if (token.type === 'table_open') count++;
        if (token.type === 'html_block') errors.push('Raw HTML block is outside the Markdown output contract.');
        if (token.type === 'fence' || token.type === 'code_block') errors.push('Code block is not a rendered Markdown table.');
        (token.children || []).forEach(function(child) {
            if (child.type === 'html_inline' && !/^<br\s*\/?>$/i.test(child.content))
                errors.push('Unsupported raw inline HTML.');
        });
    });
    // Tokenize the trusted renderer's HTML as text; no DOM, web view, or HTML execution.
    // Keep the legacy evaluator's rendered-text behavior, including structural newlines.
    var html = md.renderer.render(tokens, md.options, {});
    var tables = [], gaps = [''], depth = 0, cell = null, row = null;
    var parts = html.match(/<!--[\s\S]*?-->|<![^>]*>|<\/?[A-Za-z][^>]*>|[^<]+|</g) || [];
    parts.forEach(function(part) {
        if (/^<!/.test(part)) return;
        var tag = /^<(\/)?([A-Za-z][\w:-]*)\b[^>]*>$/.exec(part);
        if (!tag) {
            var text = part.replace(/&(?:#[xX][\da-fA-F]+|#\d+|[A-Za-z][\w]+);/g,
                function(entity) { return md.utils.unescapeAll(entity); });
            if (cell !== null) cell += text;
            else if (!depth) gaps[gaps.length - 1] += text;
            return;
        }
        var name = tag[2].toLowerCase();
        if (!tag[1]) {
            if (name === 'table') { depth++; if (depth === 1) { tables.push([]); gaps.push(''); } }
            else if (depth && name === 'tr') row = [];
            else if (depth && (name === 'td' || name === 'th')) cell = '';
            else if (name === 'br') { if (cell !== null) cell += '\n'; else if (!depth) gaps[gaps.length-1] += '\n'; }
        } else {
            if (name === 'table') depth--;
            else if (depth && (name === 'td' || name === 'th') && cell !== null) { if(row) row.push(cell.trim()); cell = null; }
            else if (depth && name === 'tr' && row !== null) { if(tables.length) tables[tables.length-1].push(row); row = null; }
            else if (!depth && /^(p|h[1-6]|li|pre|div)$/.test(name)) gaps[gaps.length-1] += '\n';
        }
    });
    if (tables.length !== count) errors.push('Raw HTML table is not a Markdown table.');
    return JSON.stringify({tables:tables, gaps:gaps, tableCount:count, errors:errors});
}
