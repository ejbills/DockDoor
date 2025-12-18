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

def validate_title(title, issue_type):
    """Validate that the title is not just the default prefix."""
    title_stripped = title.strip()

    # Check if title is just the prefix or has minimal/placeholder content
    invalid_patterns = [
        r'^\[BUG\]$',
        r'^\[FR\]$',
        r'^\[BUG\]\s*$',
        r'^\[FR\]\s*$',
        r'^\[BUG\]\s+xyz\s*$',
        r'^\[FR\]\s+xyz\s*$',
    ]

    for pattern in invalid_patterns:
        if re.match(pattern, title_stripped, re.IGNORECASE):
            return False

    # Check if there's actual content after the prefix
    if issue_type == 'bug':
        content_after_prefix = re.sub(r'^\[BUG\]\s*', '', title_stripped, flags=re.IGNORECASE)
    elif issue_type == 'feature':
        content_after_prefix = re.sub(r'^\[FR\]\s*', '', title_stripped, flags=re.IGNORECASE)
    else:
        return True

    # Title should have at least 5 characters of actual content
    return len(content_after_prefix.strip()) >= 5

def check_duplicate_checkbox(body):
    """Check if the duplicate review checkbox is checked."""
    # Look for checked checkbox patterns
    # Allow for malformed checkboxes like [x ], [ x], [ x ], etc.
    # The pattern \[\s*[xX]\s*\] matches any variation of whitespace around the x
    pattern = r'-\s*\[\s*[xX]\s*\]\s*I have reviewed existing issues'

    if re.search(pattern, body, re.IGNORECASE):
        return True

    return False

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

    # Fetch the latest issue data from GitHub API
    # This ensures we always validate the current content, even on edited issues
    result = subprocess.run(
        ['gh', 'issue', 'view', issue_number, '--json', 'title,body,labels'],
        capture_output=True, text=True, check=True
    )
    issue_data = json.loads(result.stdout)

    issue_title = issue_data['title']
    issue_body = issue_data['body']
    issue_labels = [label['name'] for label in issue_data.get('labels', [])]

    # First, check if the duplicate review checkbox is checked
    if not check_duplicate_checkbox(issue_body):
        comment = """Thank you for your submission. However, we require all issue reporters to confirm they have reviewed existing issues to avoid duplicates.

Please review the existing issues at https://github.com/ejbills/DockDoor/issues and confirm you are not creating a duplicate before resubmitting.

If this is not a duplicate, please reopen or create a new issue and check the box confirming you have reviewed existing issues."""

        subprocess.run(
            ['gh', 'issue', 'comment', str(issue_number), '--body', comment],
            check=True
        )
        subprocess.run(
            ['gh', 'issue', 'close', str(issue_number)],
            check=True
        )
        print('Issue closed - duplicate review checkbox not checked')
        sys.exit(0)

    sections = parse_issue_body(issue_body)
    issue_type = determine_issue_type(issue_title, issue_labels)

    if not issue_type:
        print('Could not determine issue type (bug or feature request)')
        sys.exit(0)

    # Validate title
    if not validate_title(issue_title, issue_type):
        manage_labels(issue_number, False)
        print('Issue is incomplete - title is invalid (appears to be default or placeholder)')
        sys.exit(0)

    # Validate required fields
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
