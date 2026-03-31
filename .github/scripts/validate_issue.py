#!/usr/bin/env python3
import json
import re
import sys
import subprocess

BOT_MARKER = "<!-- issue-validator-bot -->"

BUG_REQUIRED_SECTIONS = ['Bug Description', 'Steps to Reproduce', 'Expected vs Actual Behavior', 'Environment']
FR_REQUIRED_SECTIONS = ['What problem does this solve?', 'Proposed solution']

BUG_TEMPLATE_MARKERS = ['Bug Description', 'Steps to Reproduce']
FR_TEMPLATE_MARKERS = ['What problem does this solve?', 'Proposed solution']


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
    cleaned = re.sub(r'^\s*-\s*\[.\]\s*I have reviewed existing issues.*$', '', cleaned, flags=re.MULTILINE | re.IGNORECASE)
    cleaned = re.sub(r'<!--.*?-->', '', cleaned, flags=re.DOTALL)
    cleaned = re.sub(r'\n+', '\n', cleaned).strip()
    return len(cleaned) == 0


def validate_title(title, issue_type):
    title_stripped = title.strip()
    prefix = r'\[BUG\]' if issue_type == 'bug' else r'\[FR\]'
    if re.match(rf'^{prefix}\s*$', title_stripped, re.IGNORECASE):
        return False
    content_after = re.sub(rf'^{prefix}\s*', '', title_stripped, flags=re.IGNORECASE)
    return len(content_after.strip()) >= 5


def check_duplicate_checkbox(body):
    return bool(re.search(r'-\s*\[\s*[xX]\s*\]\s*I have reviewed existing issues', body, re.IGNORECASE))


def determine_issue_type(title, labels):
    title_lower = title.lower()
    if '[bug]' in title_lower or 'bug' in [l.lower() for l in labels]:
        return 'bug'
    elif '[fr]' in title_lower or 'enhancement' in [l.lower() for l in labels]:
        return 'feature'
    return None


def uses_template(body, issue_type):
    markers = BUG_TEMPLATE_MARKERS if issue_type == 'bug' else FR_TEMPLATE_MARKERS
    return any(f'## {m}' in body for m in markers)


def find_existing_bot_comment(issue_number):
    result = subprocess.run(
        ['gh', 'api', f'repos/{{owner}}/{{repo}}/issues/{issue_number}/comments', '--paginate',
         '-q', f'.[] | select(.user.login == "github-actions[bot]" and (.body | contains("{BOT_MARKER}"))) | .id'],
        capture_output=True, text=True
    )
    ids = result.stdout.strip().split('\n')
    return int(ids[0]) if ids and ids[0] else None


def upsert_comment(issue_number, body):
    body_with_marker = f"{BOT_MARKER}\n{body}"
    existing_id = find_existing_bot_comment(issue_number)
    if existing_id:
        subprocess.run(
            ['gh', 'api', '--method', 'PATCH',
             f'repos/{{owner}}/{{repo}}/issues/comments/{existing_id}',
             '-f', f'body={body_with_marker}'],
            check=True
        )
    else:
        subprocess.run(
            ['gh', 'issue', 'comment', str(issue_number), '--body', body_with_marker],
            check=True
        )


def delete_bot_comment(issue_number):
    existing_id = find_existing_bot_comment(issue_number)
    if existing_id:
        subprocess.run(
            ['gh', 'api', '--method', 'DELETE',
             f'repos/{{owner}}/{{repo}}/issues/comments/{existing_id}'],
            check=True
        )


def manage_labels(issue_number, is_complete):
    complete_label = 'ready for review'
    incomplete_label = 'needs more info'

    result = subprocess.run(
        ['gh', 'issue', 'view', str(issue_number), '--json', 'labels,state'],
        capture_output=True, text=True, check=True
    )
    issue_data = json.loads(result.stdout)
    current_labels = [label['name'] for label in issue_data.get('labels', [])]
    current_state = issue_data.get('state', 'OPEN')

    if is_complete:
        if incomplete_label in current_labels:
            subprocess.run(['gh', 'issue', 'edit', str(issue_number), '--remove-label', incomplete_label], check=True)
        if complete_label not in current_labels:
            subprocess.run(['gh', 'issue', 'edit', str(issue_number), '--add-label', complete_label], check=True)
        if current_state == 'CLOSED':
            subprocess.run(['gh', 'issue', 'reopen', str(issue_number)], check=True)
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
    issue_body = issue_data['body'] or ''
    issue_labels = [label['name'] for label in issue_data.get('labels', [])]

    issue_type = determine_issue_type(issue_title, issue_labels)
    if not issue_type:
        print('Not a bug or feature request - skipping validation')
        sys.exit(0)

    if not uses_template(issue_body, issue_type):
        template = 'bug report' if issue_type == 'bug' else 'feature request'
        upsert_comment(issue_number,
            f"Hey, this issue doesn't use the {template} template. The templates help keep reports organized and make sure nothing gets missed — issues without them may get closed or looked at last. Please re-create using the template from the issue picker, thanks!")
        manage_labels(issue_number, False)
        print('Issue does not use template')
        sys.exit(0)

    problems = []

    if not check_duplicate_checkbox(issue_body):
        problems.append('Check the "I have reviewed existing issues" checkbox')

    if not validate_title(issue_title, issue_type):
        problems.append('Add a descriptive title (5+ chars after the prefix)')

    sections = parse_issue_body(issue_body)
    required = BUG_REQUIRED_SECTIONS if issue_type == 'bug' else FR_REQUIRED_SECTIONS
    missing = [s for s in required if s not in sections or is_section_empty(sections[s])]
    if missing:
        problems.append('Fill in: ' + ', '.join(f'**{s}**' for s in missing))

    if problems:
        comment = 'Hey, this issue is missing some info. Please edit and fix the following:\n' + '\n'.join(f'- {p}' for p in problems)
        upsert_comment(issue_number, comment)
        manage_labels(issue_number, False)
        print('Issue incomplete')
    else:
        delete_bot_comment(issue_number)
        manage_labels(issue_number, True)
        print('Issue complete')


if __name__ == '__main__':
    main()
