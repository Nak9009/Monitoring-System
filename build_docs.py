import os
import re
import json

def get_title(content, filename):
    # Try to extract first H1 header (# Title)
    match = re.search(r'^#\s+(.+)$', content, re.MULTILINE)
    if match:
        return match.group(1).strip()
    return filename.replace('.md', '').replace('_', ' ').title()

def main():
    root_dir = os.path.dirname(os.path.abspath(__file__))
    docs_dir = os.path.join(root_dir, 'docs')
    os.makedirs(docs_dir, exist_ok=True)

    md_files = [f for f in os.listdir(root_dir) if f.endswith('.md')]
    # Sort files logically: README first, then system architecture, then guides
    order = {
        'README.md': 0,
        'system_architecture.md': 1,
        'monitoring_system_design.md': 2,
        'installation_guide.md': 3,
        'local_testing_guide.md': 4,
        'production_deployment_guide.md': 5,
        'grafana_production_guide.md': 6,
        'zabbix_ui_guide.md': 7,
        'zabbix_ui_sample_walkthrough.md': 8,
        'services_guide.md': 9,
        'vm_testing_guide.md': 10,
        'walkthrough.md': 11
    }
    
    md_files.sort(key=lambda x: order.get(x, 99))

    docs_data = {}
    for filename in md_files:
        filepath = os.path.join(root_dir, filename)
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            title = get_title(content, filename)
            key = filename.replace('.md', '')
            docs_data[key] = {
                'title': title,
                'filename': filename,
                'content': content
            }

    # Write JS data file
    data_path = os.path.join(docs_dir, 'docs-data.js')
    with open(data_path, 'w', encoding='utf-8') as f:
        f.write(f"const DOCS_DATA = {json.dumps(docs_data, indent=2)};")

    print(f"Generated {data_path} with {len(md_files)} documentation files.")

if __name__ == '__main__':
    main()
