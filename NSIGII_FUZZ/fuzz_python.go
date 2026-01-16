#!/usr/bin/env python3
import atheris
import sys
import npl_parser # your real module

@atheris.instrument_func
def TestOneInput(data):
    fdp = atheris.FuzzedDataProvider(data)
    raw = fdp.ConsumeUnicode(sys.maxsize)
    try:
        npl_parser.parse(raw)
    except Exception:  # expected parse errors
        pass

atheris.Setup(sys.argv, TestOneInput)
atheris.Fuzz()
