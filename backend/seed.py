"""
Seed script — populates the database with Purdue campus buildings.
Safe to re-run: updates coordinates on existing rows, inserts missing ones.
Coordinates from Purdue ArcGIS campus map (ESRI feature service, WGS84).
"""
from database import engine, SessionLocal
import models

models.Base.metadata.create_all(bind=engine)
db = SessionLocal()

# (slug_id, full_name, address, latitude, longitude)
buildings_data = [
    ("walc",      "Thomas S. and Harvey D. Wilmeth Active Learning Center", "550 Stadium Mall Dr, West Lafayette, IN",      40.427404, -86.913219),
    ("hicks",     "John W. Hicks Undergraduate Library",                    "504 W State St, West Lafayette, IN",           40.424533, -86.912658),
    ("haas",      "Felix Haas Hall",                                        "250 N University St, West Lafayette, IN",      40.426827, -86.916340),
    ("lawson",    "Richard & Patricia Lawson Computer Science Building",    "305 N University St, West Lafayette, IN",      40.427787, -86.917025),
    ("knoy",      "Maurice G. Knoy Hall of Technology",                     "401 N Grant St, West Lafayette, IN",           40.427754, -86.911131),
    ("pmu",       "Purdue Memorial Union",                                  "101 N Grant St, West Lafayette, IN",           40.424975, -86.911285),
    ("hovde",     "Frederick L. Hovde Hall of Administration",              "610 Purdue Mall, West Lafayette, IN",          40.428241, -86.914432),
    ("corec",     "France A. Córdova Recreational Sports Center",           "355 N Martin Jischke Dr, West Lafayette, IN",  40.428500, -86.922400),
    ("lilly",     "Lilly Hall of Life Sciences",                            "915 W State St, West Lafayette, IN",           40.423395, -86.918161),
    ("krach",     "Krach Leadership Center",                                "190 S Grant St, West Lafayette, IN",           40.427580, -86.921270),
    ("heavilon",  "Heavilon Hall",                                          "500 Oval Dr, West Lafayette, IN",              40.425800, -86.913800),
    ("stanley",   "Stanley Coulter Hall",                                   "201 S University St, West Lafayette, IN",      40.426530, -86.914379),
    ("rec",       "Recitation Building",                                    "200 S University St, West Lafayette, IN",      40.427000, -86.913900),
    ("krannert",  "Krannert Building",                                      "403 W State St, West Lafayette, IN",           40.423693, -86.910956),
    ("stewart",   "Stewart Center",                                         "128 Memorial Mall, West Lafayette, IN",        40.425052, -86.912749),
    ("ee",        "Materials and Electrical Engineering Building",          "501 Northwestern Ave, West Lafayette, IN",     40.429345, -86.912669),
    ("arms",      "Neil Armstrong Hall of Engineering",                     "701 W Stadium Ave, West Lafayette, IN",        40.430975, -86.914995),
]

# Map slug → expected DB id (walc=1, hicks=2, haas=3 already exist)
slug_to_name = {slug: name for slug, name, *_ in buildings_data}

for slug, name, location, lat, lng in buildings_data:
    row = db.query(models.Building).filter_by(name=name).first()
    if row:
        row.location  = location
        row.latitude  = lat
        row.longitude = lng
        print(f"Updated  Building id={row.id}: {name}")
    else:
        row = models.Building(name=name, location=location, latitude=lat, longitude=lng)
        db.add(row)
        db.flush()
        print(f"Created  Building id={row.id}: {name}")

db.commit()
db.close()
print("\nSeed complete.")
