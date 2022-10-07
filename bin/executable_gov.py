#!/bin/env python

import argparse
import json
import re
import requests


def pa(nr_wniosku: str) -> str:
    uri = "https://obywatel.gov.pl/wyjazd-za-granice/sprawdz-czy-twoj-paszport-jest-gotowy"
    try:
        s = requests.Session()
        r1 = s.get(uri)

        data_auth = re.search(R"data-auth=\"(.*?)\"", r1.content.decode()).groups()[0]
        data_href = re.search(R"data-href=\"(.*?)\"", r1.content.decode()).groups()[0]
        payload = f"_Gotowoscpaszportu_WAR_Gotowoscpaszportuportlet_nrSprawy={nr_wniosku}&_Gotowoscpaszportu_WAR_Gotowoscpaszportuportlet_p_auth={data_auth}"
        headers = {"Content-Type": "application/x-www-form-urlencoded"}
        r2 = s.post(data_href, data=payload, headers=headers)

        if r2.ok:
            content = json.loads(r2.content.decode())[0]
            status = content["status"]
            return f"Wniosek nr: {nr_wniosku} - {status}"
        else:
            return f"Error: {r2.status_code} - {r2.reason}"
    except Exception as e:
        return e


def do(nr_wniosku: str) -> str:
    uri = f"https://obywatel.gov.pl/esrvProxy/proxy/sprawdzStatusWniosku?numerWniosku={nr_wniosku}"
    try:
        r = requests.get(uri)

        if r.ok:
            content = json.loads(r.content.decode())
            status = content["status"]["message"].replace("&#160;", " ")
            return f"Wniosek nr: {nr_wniosku} - {status}"
        else:
            return f"Error: {r.status_code} - {r.reason}"
    except Exception as e:
        return e


def dr(nr_rej: str, nr_vin: str) -> str:
    uri = "https://info-car.pl/api/ssi/status/driver/registration-document"
    try:
        requests.packages.urllib3.util.ssl_.DEFAULT_CIPHERS += "HIGH:!DH:!aNULL"
        payload = {"registrationNumber": nr_rej, "vin": nr_vin[-5:]}
        headers = {"Content-Type": "application/json"}
        r = requests.post(uri, data=json.dumps(payload), headers=headers)

        if r.ok:
            content = json.loads(r.content.decode())
            status = content["statusHistory"][-1]["description"]
            return f"Dowód rej. nr: {nr_rej} - {status}"
        else:
            return f"Error: {r.status_code} - {r.reason}"
    except Exception as e:
        return e


def main() -> None:
    try:
        parser = argparse.ArgumentParser()
        subparsers = parser.add_subparsers(help="dokumenty")
        sp = subparsers.add_parser("pa", help="paszport")
        sp.set_defaults(dok="pa")
        sp.add_argument("nr_wniosku", help="nr wniosku")
        sp = subparsers.add_parser("do", help="dowód osobisty")
        sp.set_defaults(dok="do")
        sp.add_argument("nr_wniosku", help="nr wniosku")
        sp = subparsers.add_parser("dr", help="dowód rejestracyjny")
        sp.set_defaults(dok="dr")
        sp.add_argument("nr_rej", help="nr rejestracyjny")
        sp.add_argument("nr_vin", help="nr VIN (pełny lub ostatnie 5 cyfr)")

        args = parser.parse_args()

        if args.dok == "pa":
            print(pa(args.nr_wniosku))
        elif args.dok == "do":
            print(do(args.nr_wniosku))
        elif args.dok == "dr":
            print(dr(args.nr_rej, args.nr_vin))

    except SystemExit:
        pass
    except Exception as e:
        print(f"Error: {e}\n")
        parser.print_help()


if __name__ == "__main__":
    main()
