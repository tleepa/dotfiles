#!/bin/env python

import argparse
import random
import string


def randomPassword(stringLength):
    chars1 = string.ascii_lowercase.replace("y", "").replace("z", "").replace("l", "")
    chars2 = (
        string.ascii_uppercase.replace("Y", "")
        .replace("Z", "")
        .replace("O", "")
        .replace("I", "")
    )
    chars3 = "!@#$%^&*()"
    chars4 = string.digits

    randomSource = chars1 + chars2 + chars3 + chars4
    password = random.choice(chars1)
    password += random.choice(chars2)
    password += random.choice(chars3)
    password += random.choice(chars4)

    for _ in range(stringLength - 4):
        password += random.choice(randomSource)

    passwordList = list(password)
    random.SystemRandom().shuffle(passwordList)
    password = "".join(passwordList)
    return password


def main():
    try:
        parser = argparse.ArgumentParser()
        parser.add_argument(
            "pwd_length", help="length of the password", type=int, default=16, nargs="?"
        )
        args = parser.parse_args()

        print(randomPassword(args.pwd_length))

    except SystemExit:
        pass
    except Exception as e:
        print(f"Error: {e}\n")
        parser.print_help()


if __name__ == "__main__":
    main()
