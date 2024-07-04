
def appcast_contains_version(version):
    with open('docs/Support/appcast.xml', 'r') as f:
        return version in f.read()

def get_first(str, lines):
    for line in lines:
        if str in line:
            return lines.index(line)

def remove_last_item_in_appcast():
    lines = []
    with open('docs/Support/appcast.xml', 'r') as f:
        lines = f.readlines()
        start_index = get_first("<item>", lines)
        end_index = get_first("</item>", lines)
        lines = lines[:start_index] + lines[end_index+1:]
    with open('docs/Support/appcast.xml', 'w') as f:
        f.writelines(lines)

def get_last_item_in_appcast():
    with open('docs/Support/appcast.xml', 'r') as f:
        lines = f.readlines()
        start_index = get_first("<item>", lines)
        end_index = get_first("</item>", lines)
        return ' '.join(lines[start_index:end_index+1])

def item_channel_is_beta(item):
    return "beta" in item

if __name__ == '__main__':
    with open('new_version', 'r') as new_version_file:
        new_version = new_version_file.read()
        last_item = get_last_item_in_appcast()
        if(new_version in last_item):
            print("Last item in appcast.xml contains new_version")
            if(item_channel_is_beta(last_item)):
                remove_last_item_in_appcast()
                print("removed last item in appcast.xml")
        else:
            print("last item is not new_version")
