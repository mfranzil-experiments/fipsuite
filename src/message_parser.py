from argparse import ArgumentParser
import json


def parse(filename="matches.json"):
    data = json.loads(open(filename).read())
    for item in data:
        words = item.split(" ")
        gara = {}
        # Primo oggetto è sempre il comitato.
        # Se inizia con CR o NAZIONALE, sicuramente esiste un numero di gara, quindi
        # parso finché non trovo un numero.
        # Altrimenti, parso finché non trovo S, C o 24.
        if words[0].startswith("CR") or words[0].startswith("NAZIONALE"):
            i = 1
            while True:
                try:
                    int(words[i])
                    break
                except ValueError:
                    i += 1
            numero_gara = words[i]
            gara["numero_gara"] = int(numero_gara)

            comitato = " ".join(words[:i-1])
            gara["comitato"] = comitato

            serie = words[i - 1]
            gara["serie"] = serie
        else:
            i = 0
            while i + 1 < len(words):
                if words[i+1][:2] == "S:" or words[i+1][:2] == "C:" or words[i+1][:3] == "24:":
                    break
                i += 1

            split = False
            try:
                int(words[i])
                numero_gara = words[i]
                gara["numero_gara"] = int(numero_gara)
                split = True
            except ValueError:
                pass

            index = i + 1 if not split else i
            comitato = " ".join(words[:index])
            gara["comitato"] = comitato

        # Now parse S, C or 24
        i += 1
        while words[i][:2] == "S:" or words[i][:2] == "C:" or words[i][:3] == "24:":
            role, name = words[i].split(":")

            # Fix for names with two words which get split.
            # For now it checks common surnames which start in "de"
            if name.lower().endswith(".de") or name.lower().endswith(".da") \
              or name.lower().endswith(".del") or name.lower().endswith(".dal"):
                name = words[i] + " " + words[i+1]
                i += 1

            if "udc" not in gara:
                gara["udc"] = {}

            gara["udc"][role] = name
            i += 1

        # Parse the teams. They are separated by a "/"

        if "/" in words[i]:
            teams = words[i].split("/")
            gara["casa"] = teams[0]
            gara["fuori"] = teams[1]
        else:
            gara["casa"] = ""
            while "/" not in words[i]:
                gara["casa"] += " " + words[i]
                i += 1
            finecasa, iniziofuori = words[i].split("/")
            gara["casa"] += " " + finecasa
            gara["casa"] = gara["casa"].strip()
            gara["fuori"] = iniziofuori

        # Keep going until we find a date
        i = i + 1
        j = i
        while True:
            if words[i][0:2].isnumeric() and words[i][3:5].isnumeric() and words[i][6:10].isnumeric() \
              and words[i][2] == "/" and words[i][5] == "/":
                break
            i += 1
        gara["fuori"] = gara["fuori"] + " " + " ".join(words[j:i])
        gara["fuori"] = gara["fuori"].strip()

        # Parse the date and time
        gara["data"] = words[i]
        gara["ora"] = words[(i := i + 1)]

        # Until we find a CAP (5-digit number) that's the gym
        j = i + 1
        while True:
            if words[i].isnumeric() and len(words[i]) == 5:
                break
            i += 1
        gara["gym"] = " ".join(words[j:i])
        gara["cap"] = words[i]

        # Finally, the place
        gara["luogo"] = " ".join(words[(i := i + 1):-1])
        gara["provincia"] = words[-1].replace("(", "").replace(")", "")

        print(json.dumps(gara, indent=4))


if __name__ == "__main__":
    parser = ArgumentParser()
    parser.add_argument("--input", "-i", help="Input file", required=True)
    args = parser.parse_args().__dict__
    parse(args["input"])
