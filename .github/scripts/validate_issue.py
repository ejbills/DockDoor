#!/usr/bin/env python3
import json
import re
import sys
import subprocess

def parse_issue_body(body):
    sections = {}
    current_section = None
    current_content = []

    for line in body.split('\n'):
        stripped = line.lstrip()
        if stripped.startswith('##'):
            if current_section:
                sections[current_section] = '\n'.join(current_content).strip()

            current_section = stripped.replace('#', '').strip()
            current_content = []
        else:
            current_content.append(line)

    if current_section:
        sections[current_section] = '\n'.join(current_content).strip()

    return sections

def is_section_empty(content):
    if not content:
        return True

    cleaned = content.strip()
    cleaned = re.sub(r'^\s*\d+\.\s*$', '', cleaned, flags=re.MULTILINE)
    cleaned = re.sub(r'^\s*-\s*$', '', cleaned, flags=re.MULTILINE)
    cleaned = re.sub(r'^\s*-\s*[^:]+:\s*$', '', cleaned, flags=re.MULTILINE)
    cleaned = re.sub(r'\n+', '\n', cleaned)
    cleaned = cleaned.strip()

    return len(cleaned) == 0

def validate_bug_report(sections):
    """Validate bug report template."""
    required_fields = {
        'Bug Description': 'Bug Description',
        'Steps to Reproduce': 'Steps to Reproduce',
        'Expected vs Actual Behavior': 'Expected vs Actual Behavior',
        'Environment': 'Environment'
    }

    missing = []
    for field_name, display_name in required_fields.items():
        if field_name not in sections or is_section_empty(sections[field_name]):
            missing.append(f"- **{display_name}**")

    return missing

def validate_feature_request(sections):
    """Validate feature request template."""
    required_fields = {
        'What problem does this solve?': 'What problem does this solve?',
        'Proposed solution': 'Proposed solution'
    }

    missing = []
    for field_name, display_name in required_fields.items():
        if field_name not in sections or is_section_empty(sections[field_name]):
            missing.append(f"- **{display_name}**")

    return missing

def determine_issue_type(title, labels):
    title_lower = title.lower()

    if '[bug]' in title_lower or 'bug' in [l.lower() for l in labels]:
        return 'bug'
    elif '[fr]' in title_lower or 'enhancement' in [l.lower() for l in labels]:
        return 'feature'

    return None

def manage_labels(issue_number, is_complete):
    complete_label = 'ready for review'
    incomplete_label = 'needs more info'

    result = subprocess.run(
        ['gh', 'issue', 'view', str(issue_number), '--json', 'labels'],
        capture_output=True, text=True, check=True
    )
    labels_data = json.loads(result.stdout)
    current_labels = [label['name'] for label in labels_data.get('labels', [])]

    if is_complete:
        if incomplete_label in current_labels:
            subprocess.run(['gh', 'issue', 'edit', str(issue_number), '--remove-label', incomplete_label], check=True)
        if complete_label not in current_labels:
            subprocess.run(['gh', 'issue', 'edit', str(issue_number), '--add-label', complete_label], check=True)
    else:
        if complete_label in current_labels:
            subprocess.run(['gh', 'issue', 'edit', str(issue_number), '--remove-label', complete_label], check=True)
        if incomplete_label not in current_labels:
            subprocess.run(['gh', 'issue', 'edit', str(issue_number), '--add-label', incomplete_label], check=True)

def main():
    if len(sys.argv) < 2:
        print('Usage: validate_issue.py <issue_number>')
        sys.exit(1)

    issue_number = sys.argv[1]

    result = subprocess.run(
        ['gh', 'issue', 'view', issue_number, '--json', 'title,body,labels'],
        capture_output=True, text=True, check=True
    )
    issue_data = json.loads(result.stdout)

    issue_title = issue_data['title']
    issue_body = issue_data['body']
    issue_labels = [label['name'] for label in issue_data.get('labels', [])]

    sections = parse_issue_body(issue_body)
    issue_type = determine_issue_type(issue_title, issue_labels)

    if not issue_type:
        print('Could not determine issue type (bug or feature request)')
        sys.exit(0)

    if issue_type == 'bug':
        missing_fields = validate_bug_report(sections)
    else:
        missing_fields = validate_feature_request(sections)

    if missing_fields:
        manage_labels(issue_number, False)
        print(f'Issue is incomplete - missing: {", ".join(missing_fields)}')
    else:
        manage_labels(issue_number, True)
        print('Issue is complete')

if __name__ == '__main__':
    main()
