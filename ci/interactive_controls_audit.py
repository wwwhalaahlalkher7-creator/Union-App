#!/usr/bin/env python3
"""Dependency-free static regression audit for website interactive controls."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit
import re, sys
ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / 'website'
class Scan(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True); self.tags=[]; self.stack=[]
    def handle_starttag(self, tag, attrs):
        a=dict(attrs); self.tags.append((tag,a,tuple(self.stack)))
        if tag not in {'area','base','br','col','embed','hr','img','input','link','meta','param','source','track','wbr'}:
            self.stack.append(tag)
    def handle_startendtag(self, tag, attrs): self.tags.append((tag,dict(attrs),tuple(self.stack)))
    def handle_endtag(self, tag):
        for i in range(len(self.stack)-1,-1,-1):
            if self.stack[i]==tag: del self.stack[i:]; break
errors=[]; pages=list(SITE.rglob('*.html')); button_count=link_count=form_count=0
for page in pages:
    source=page.read_text(encoding='utf-8', errors='replace'); scan=Scan(); scan.feed(source)
    scripts=source
    for tag, attrs, parents in scan.tags:
        if tag=='script' and attrs.get('src'):
            src=attrs['src'].split('?',1)[0]; candidate=(page.parent/src).resolve()
            if not candidate.exists(): candidate=(SITE/src).resolve()
            if not candidate.exists(): errors.append(f'{page.relative_to(ROOT)}: missing script {attrs["src"]}')
            elif candidate.suffix=='.js': scripts += '\n'+candidate.read_text(encoding='utf-8',errors='replace')
    for tag,a,parents in scan.tags:
        if tag=='form': form_count+=1
        if tag in {'button'} or (tag=='input' and a.get('type','').lower() in {'button','submit'}) or a.get('role')=='button':
            button_count+=1; ident=a.get('id'); explicit=bool(a.get('onclick') or a.get('data-action') or (tag=='input' and a.get('type','').lower()=='submit') or 'form' in parents)
            if ident and not explicit:
                esc=re.escape(ident)
                referenced=bool(re.search(r'(?:getElementById\([\'\"]'+esc+r'[\'\"]\)|querySelector\([\'\"]#[^\'\"]*'+esc+r'[\'\"]\)|\[id=[\'\"]'+esc+r'[\'\"]\])', scripts))
                if not referenced and not a.get('data-testid') and 'template' not in parents:
                    errors.append(f'{page.relative_to(ROOT)}: control #{ident} has no static handler reference')
        if tag=='a':
            link_count+=1; href=a.get('href')
            if href is None or not href.strip() or href.strip()=='#':
                if a.get('aria-disabled')!='true': errors.append(f'{page.relative_to(ROOT)}: placeholder link #{a.get("id") or "(no id)"} is not explicitly disabled')
                continue
            parsed=urlsplit(href.strip())
            if parsed.scheme or href.strip().startswith('//') or href.strip().startswith('#'): continue
            local=parsed.path
            if not local: continue
            target=(page.parent/local).resolve()
            if not target.exists(): target=(SITE/local).resolve()
            if not target.exists(): errors.append(f'{page.relative_to(ROOT)}: broken local link {href}')
# Regression: the download page's responsive menu must be a keyboard-accessible
# button with a real click handler that toggles the nav's active state.
download_html = (SITE / 'download.html').read_text(encoding='utf-8')
for required in (
    'id="menuToggle" type="button"',
    'aria-controls="navMenu"',
    "menuToggle.addEventListener('click'",
    "navMenu.classList.contains('active')",
    "setMenuOpen(!navMenu.classList.contains('active'))",
):
    if required not in download_html:
        errors.append(f'website/download.html: missing responsive menu behavior: {required}')
print(f'Interactive control inventory: {len(pages)} HTML pages, {button_count} buttons, {link_count} links, {form_count} forms')
if errors:
    print(f'INTERACTIVE CONTROLS AUDIT FAILED ({len(errors)} findings)')
    for e in errors: print(' - '+e)
    sys.exit(1)
print('INTERACTIVE CONTROLS STATIC AUDIT PASSED')
