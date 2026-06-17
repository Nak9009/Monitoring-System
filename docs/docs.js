/* ============================================================================
   Enterprise Monitoring Stack — Portal Logic
   ============================================================================ */

// Fallback in case docs-data.js fails to load or is not found
if (typeof DOCS_DATA === 'undefined') {
    window.DOCS_DATA = {
        "README": {
            "title": "Offline Portal (No Data Loaded)",
            "filename": "README.md",
            "content": "# Offline Documentation Portal\n\nNo compiled documentation data was found.\n\n### 🔧 How to fix:\n1. Make sure you have run the compiler script in the root directory:\n   ```bash\n   python3 build_docs.py\n   ```\n2. Verify that `docs/docs-data.js` exists and is populated.\n3. Reload this page."
        }
    };
}

function initPortal() {
    let currentKey = 'README';
    const menuToggle = document.getElementById('menu-toggle');
    const sidebar = document.querySelector('.sidebar');
    const sidebarNav = document.getElementById('sidebar-nav');
    const searchInput = document.getElementById('search-input');
    const themeToggle = document.getElementById('theme-toggle');
    const contentBody = document.getElementById('content-body');
    const tocNav = document.getElementById('toc-nav');
    
    const breadcrumbCategory = document.getElementById('breadcrumb-category');
    const breadcrumbPage = document.getElementById('breadcrumb-page');

    // Initialize Theme
    const savedTheme = localStorage.getItem('theme') || 'dark';
    document.documentElement.setAttribute('data-theme', savedTheme);
    
    // Initialize Mermaid if loaded
    if (typeof mermaid !== 'undefined' && mermaid.initialize) {
        mermaid.initialize({
            startOnLoad: false,
            theme: savedTheme === 'dark' ? 'dark' : 'default',
            securityLevel: 'loose',
            fontFamily: 'Inter, sans-serif'
        });
    }

    // Render Navigation Links
    function renderNav(activeKey, filter = '') {
        if (!sidebarNav) return;
        sidebarNav.innerHTML = '';
        const keys = Object.keys(DOCS_DATA);
        
        keys.forEach(key => {
            const doc = DOCS_DATA[key];
            if (filter && !doc.title.toLowerCase().includes(filter.toLowerCase()) && !doc.content.toLowerCase().includes(filter.toLowerCase())) {
                return;
            }
            
            const item = document.createElement('a');
            item.className = `nav-item ${key === activeKey ? 'active' : ''}`;
            
            // Icon mapping based on document type
            let icon = 'file-text';
            if (key.includes('architecture') || key.includes('design')) icon = 'map';
            if (key.includes('install') || key.includes('deploy')) icon = 'server';
            if (key.includes('testing')) icon = 'terminal';
            if (key.includes('guide') && !key.includes('deploy')) icon = 'book-open';
            if (key.includes('walkthrough')) icon = 'check-circle';
            if (key === 'README') icon = 'home';
            
            item.innerHTML = `<i data-lucide="${icon}"></i><span>${doc.title}</span>`;
            item.addEventListener('click', () => {
                loadPage(key);
                if (window.innerWidth <= 900 && sidebar) {
                    sidebar.classList.remove('open');
                }
            });
            sidebarNav.appendChild(item);
        });
        
        // Trigger Lucide icons safely
        if (typeof lucide !== 'undefined' && lucide.createIcons) {
            lucide.createIcons();
        }
    }

    // Helper for Alert Icons
    function getAlertIcon(type) {
        switch(type.toUpperCase()) {
            case 'NOTE': return 'info';
            case 'TIP': return 'lightbulb';
            case 'IMPORTANT': return 'alert-circle';
            case 'WARNING': return 'alert-triangle';
            case 'CAUTION': return 'shield-alert';
            default: return 'info';
        }
    }

    // Preprocess GFM Alert Blocks
    function preprocessMarkdown(text) {
        const lines = text.split('\n');
        let inQuote = false;
        let quoteLines = [];
        let alertType = null;
        let output = [];
        
        for (let i = 0; i < lines.length; i++) {
            let line = lines[i];
            let match = line.match(/^\>\s*\[\!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*$/i);
            if (match) {
                if (inQuote) {
                    output.push(`<div class="alert-box alert-${alertType.toLowerCase()}">`);
                    output.push(`<div class="alert-title"><i data-lucide="${getAlertIcon(alertType)}"></i>${alertType}</div>`);
                    if (typeof marked !== 'undefined' && marked.parse) {
                        output.push(marked.parse(quoteLines.join('\n')));
                    } else {
                        output.push(quoteLines.join('<br>'));
                    }
                    output.push('</div>');
                }
                inQuote = true;
                alertType = match[1].toUpperCase();
                quoteLines = [];
                continue;
            }
            
            if (inQuote) {
                if (line.trim().startsWith('>')) {
                    let quoteText = line.substring(line.indexOf('>') + 1);
                    if (quoteText.startsWith(' ')) {
                        quoteText = quoteText.substring(1);
                    }
                    quoteLines.push(quoteText);
                } else {
                    inQuote = false;
                    output.push(`<div class="alert-box alert-${alertType.toLowerCase()}">`);
                    output.push(`<div class="alert-title"><i data-lucide="${getAlertIcon(alertType)}"></i>${alertType}</div>`);
                    if (typeof marked !== 'undefined' && marked.parse) {
                        output.push(marked.parse(quoteLines.join('\n')));
                    } else {
                        output.push(quoteLines.join('<br>'));
                    }
                    output.push('</div>');
                    output.push(line);
                }
            } else {
                output.push(line);
            }
        }
        
        if (inQuote) {
            output.push(`<div class="alert-box alert-${alertType.toLowerCase()}">`);
            output.push(`<div class="alert-title"><i data-lucide="${getAlertIcon(alertType)}"></i>${alertType}</div>`);
            if (typeof marked !== 'undefined' && marked.parse) {
                output.push(marked.parse(quoteLines.join('\n')));
            } else {
                output.push(quoteLines.join('<br>'));
            }
            output.push('</div>');
        }
        
        return output.join('\n');
    }

    // Load and Render Page
    function loadPage(key) {
        if (!DOCS_DATA[key]) return;
        currentKey = key;
        
        const doc = DOCS_DATA[key];
        
        if (breadcrumbPage) breadcrumbPage.textContent = doc.title;
        if (breadcrumbCategory) {
            breadcrumbCategory.textContent = key === 'README' ? 'Start' : (key.includes('guide') ? 'Guides' : 'Infrastructure');
        }
        
        const processedMarkdown = preprocessMarkdown(doc.content);
        
        let renderer = null;
        if (typeof marked !== 'undefined' && marked.Renderer) {
            renderer = new marked.Renderer();
            renderer.code = function(codeOrObj, lang, escaped) {
                let codeText = '';
                let codeLang = '';
                
                if (typeof codeOrObj === 'object' && codeOrObj !== null) {
                    codeText = codeOrObj.text || '';
                    codeLang = codeOrObj.lang || '';
                } else {
                    codeText = codeOrObj || '';
                    codeLang = lang || '';
                }
                
                if (codeLang === 'mermaid') {
                    return `<div class="mermaid">${codeText}</div>`;
                }
                
                const escapedCode = codeText.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
                return `
                <div class="code-block-container">
                    <div class="code-block-header">
                        <span class="code-block-lang">${codeLang || 'text'}</span>
                        <button class="copy-code-btn" onclick="copyCode(this)">
                            <i data-lucide="clipboard"></i>
                            <span>Copy</span>
                        </button>
                    </div>
                    <pre class="language-${codeLang}"><code class="language-${codeLang}">${escapedCode}</code></pre>
                </div>`;
            };
        }
        
        // Render Content (with safety check if Marked CDN failed)
        if (contentBody) {
            if (typeof marked !== 'undefined' && marked.parse) {
                contentBody.innerHTML = `<div class="content-container-card">${marked.parse(processedMarkdown, { renderer })}</div>`;
            } else {
                const escapedContent = processedMarkdown.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
                contentBody.innerHTML = `
                <div class="content-container-card">
                    <div class="alert-box alert-warning">
                        <div class="alert-title"><i data-lucide="alert-triangle"></i>Offline Mode (No CDN)</div>
                        Interactive markdown rendering is unavailable because Marked.js CDN could not be reached. Showing plain text.
                    </div>
                    <pre style="white-space: pre-wrap; font-family: monospace;">${escapedContent}</pre>
                </div>`;
            }
        }
        
        // Render Table of Contents
        renderTOC();
        
        // Highlight Code
        if (typeof Prism !== 'undefined' && Prism.highlightAll) {
            Prism.highlightAll();
        }
        
        // Render Mermaid Diagrams
        if (typeof mermaid !== 'undefined' && mermaid.run) {
            try {
                const currentTheme = document.documentElement.getAttribute('data-theme');
                mermaid.initialize({ theme: currentTheme === 'dark' ? 'dark' : 'default' });
                mermaid.run({
                    nodes: document.querySelectorAll('.mermaid')
                });
            } catch (err) {
                console.error("Mermaid rendering error: ", err);
            }
        }
        
        // Re-render Nav sidebar active links
        renderNav(key, searchInput ? searchInput.value : '');
        
        if (typeof lucide !== 'undefined' && lucide.createIcons) {
            lucide.createIcons();
        }
    }

    // Table of Contents Generator
    function renderTOC() {
        if (!tocNav || !contentBody) return;
        tocNav.innerHTML = '';
        const headings = contentBody.querySelectorAll('h2, h3');
        
        if (headings.length === 0) {
            tocNav.innerHTML = '<span class="text-muted">No headings on this page</span>';
            return;
        }
        
        headings.forEach((heading, index) => {
            const text = heading.textContent;
            const id = heading.id || text.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '') + '-' + index;
            heading.id = id;
            
            const link = document.createElement('a');
            link.className = `toc-link ${heading.tagName.toLowerCase()}`;
            link.textContent = text;
            link.addEventListener('click', (e) => {
                e.preventDefault();
                heading.scrollIntoView({ behavior: 'smooth' });
            });
            tocNav.appendChild(link);
        });
    }

    // Search Box Listener
    if (searchInput) {
        searchInput.addEventListener('input', (e) => {
            const val = e.target.value;
            renderNav(currentKey, val);
        });
    }

    // Mobile Menu Toggle Button
    if (menuToggle && sidebar) {
        menuToggle.addEventListener('click', () => {
            sidebar.classList.toggle('open');
        });
    }

    // Theme Switcher Button
    if (themeToggle) {
        themeToggle.addEventListener('click', () => {
            const currentTheme = document.documentElement.getAttribute('data-theme');
            const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
            document.documentElement.setAttribute('data-theme', newTheme);
            localStorage.setItem('theme', newTheme);
            
            if (typeof mermaid !== 'undefined' && mermaid.initialize) {
                mermaid.initialize({ theme: newTheme === 'dark' ? 'dark' : 'default' });
                loadPage(currentKey);
            }
        });
    }

    // Global Hotkeys
    document.addEventListener('keydown', (e) => {
        if (!searchInput) return;
        if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
            e.preventDefault();
            searchInput.focus();
            searchInput.select();
        } else if (e.key === '/' && document.activeElement !== searchInput) {
            e.preventDefault();
            searchInput.focus();
            searchInput.select();
        }
    });

    // Start by loading the default README page
    loadPage('README');
}

// Resilient DOM Ready Checker
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initPortal);
} else {
    initPortal();
}

// Global Copy Code Helper Function
window.copyCode = function(btn) {
    const pre = btn.closest('.code-block-container').querySelector('pre');
    if (!pre) return;
    const code = pre.textContent;
    
    navigator.clipboard.writeText(code).then(() => {
        const span = btn.querySelector('span');
        const iconContainer = btn.querySelector('i') || btn.querySelector('svg');
        
        span.textContent = 'Copied!';
        btn.classList.add('copied');
        
        if (iconContainer && typeof lucide !== 'undefined' && lucide.createIcons) {
            iconContainer.outerHTML = '<i data-lucide="check" class="copy-icon"></i>';
            lucide.createIcons();
        }
        
        setTimeout(() => {
            span.textContent = 'Copy';
            btn.classList.remove('copied');
            const newIcon = btn.querySelector('svg') || btn.querySelector('i');
            if (newIcon && typeof lucide !== 'undefined' && lucide.createIcons) {
                newIcon.outerHTML = '<i data-lucide="clipboard"></i>';
                lucide.createIcons();
            }
        }, 2000);
    }).catch(err => {
        console.error('Failed to copy text: ', err);
    });
};
