#!/usr/bin/env python3

import argparse
import requests

API = "https://api.github.com/repos/doocs/leetcode/contents/solution"


def folder_name(qno: int) -> str:
    start = (qno // 100) * 100
    if qno < 100:
        start = 0
    end = start + 99
    return f"{start:04d}-{end:04d}"


def find_problem_folder(group: str, qno: int):
    url = f"{API}/{group}"

    r = requests.get(url)
    r.raise_for_status()

    prefix = f"{qno}."

    for item in r.json():
        if item["type"] == "dir" and item["name"].startswith(prefix):
            return item["name"]

    return None


def fetch_solution(group: str, folder: str):
    raw = (
        "https://raw.githubusercontent.com/"
        "doocs/leetcode/main/"
        f"solution/{group}/{folder}/Solution.py"
    )

    r = requests.get(raw)

    if r.status_code != 200:
        return None

    return r.text


def process(qno: int):
    group = folder_name(qno)

    try:
        folder = find_problem_folder(group, qno)
    except Exception as e:
        print(f"\nQuestion {qno}: ERROR ({e})")
        return

    if folder is None:
        print(f"\nQuestion {qno}: NOT FOUND")
        return

    code = fetch_solution(group, folder)

    if code is None:
        print(f"\nQuestion {qno}: Solution.py NOT FOUND")
        return

    title = folder.split(".", 1)[1]

    print("=" * 80)
    print(f"Question {qno}: {title}")
    print("=" * 80)
    print(code.rstrip())
    print()


def expand(values):
    nums = []

    for item in values:
        if "-" in item:
            a, b = map(int, item.split("-"))
            nums.extend(range(a, b + 1))
        else:
            nums.append(int(item))

    return nums


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "questions",
        nargs="+",
        help="Question numbers or ranges (e.g. 1 42 100-110)"
    )

    args = parser.parse_args()

    for q in expand(args.questions):
        process(q)


if __name__ == "__main__":
    main()
